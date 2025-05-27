import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // Para jsonEncode y utf8
import 'dart:async'; // Para Future

class DBHelper {
  static Database? _db;
  static const int dbVersion = 3; 

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mi_app.db');
    print("[DBHelper._initDb] Ruta de la base de datos: $path");

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        print("[DBHelper._initDb] onCreate - Creando tablas para la versión: $version");
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print("[DBHelper._initDb] onUpgrade - Actualizando de v$oldVersion a v$newVersion");
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE proyectos(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              usuario_id INTEGER,
              nombre_proyecto TEXT NOT NULL,
              respuestas_json TEXT,
              resultado_ia_json TEXT,
              fecha_creacion TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
              fecha_modificacion TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
              FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
            )
          ''');
          print("[DBHelper._initDb] Tabla 'proyectos' creada en onUpgrade (desde v$oldVersion).");
        }
        if (oldVersion < 3) {
          await db.execute('''
            ALTER TABLE proyectos ADD COLUMN firestore_project_id TEXT NULL
          ''');
          print("[DBHelper._initDb] Columna 'firestore_project_id' añadida a 'proyectos' en onUpgrade (desde v$oldVersion).");
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        print("[DBHelper._initDb] PRAGMA foreign_keys = ON ejecutado.");
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE,
        contraseña TEXT,
        status INTEGER DEFAULT 0 
      )
    ''');
    
    print("[DBHelper._createTables] Tabla 'usuarios' creada.");

    await db.execute('''
      CREATE TABLE proyectos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER,
        nombre_proyecto TEXT NOT NULL,
        respuestas_json TEXT,
        resultado_ia_json TEXT,
        fecha_creacion TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
        fecha_modificacion TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
        firestore_project_id TEXT NULL,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');
    print("[DBHelper._createTables] Tabla 'proyectos' creada.");
  }

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // --- MÉTODOS DE USUARIO

  static Future<int> insertarUsuario(String email, String password, {int status = 1, String? firebaseAuthUid}) async {
    final db = await database;
    email = email.toLowerCase().trim(); // Normalizar email
    String finalPassword = (password == "[GOOGLE_USER]" || password == "[APPLE_USER]") ? password : hashPassword(password);

  
    if (status == 1) {
        try {
            int deactivatedCount = await db.update('usuarios', {'status': 0}, where: 'email != ?', whereArgs: [email]);
            print("[DBHelper.insertarUsuario] Previo a insertar/actualizar $email: $deactivatedCount otros usuarios puestos a status 0.");
        } catch (e) {
            print("[DBHelper.insertarUsuario] Error al desactivar otros usuarios para $email: $e");
        }
    }
    
    Map<String, dynamic> row = {
      'email': email,
      'contraseña': finalPassword,
      'status': status,
    };

    int resultId = -1;
    print("[DBHelper.insertarUsuario] Intentando insertar/actualizar usuario: $email, status deseado: $status");

    try {
      // Intenta insertar. Si el email (UNIQUE) ya existe, ConflictAlgorithm.ignore lo omite.
      await db.insert(
        'usuarios',
        row, // El 'status' aquí es el deseado
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      print("[DBHelper.insertarUsuario] Intento de INSERT (ignore) completado para $email.");

  
      int updatedRows = await db.update(
        'usuarios',
        {'status': status, 'contraseña': finalPassword}, // Asegura que el status y contraseña se actualicen
        where: 'email = ?',
        whereArgs: [email],
      );

      print("[DBHelper.insertarUsuario] UPDATE para $email completado. Filas afectadas: $updatedRows. Status debería ser: $status.");

      final List<Map<String, dynamic>> users = await db.query('usuarios', where: 'email = ?', whereArgs: [email], limit: 1);
      if (users.isNotEmpty) {
        resultId = users.first['id'] as int;
        print("[DBHelper.insertarUsuario] Usuario $email (ID: $resultId) tiene AHORA status: ${users.first['status']} y contraseña: ${users.first['contraseña'] == finalPassword ? 'coincide' : 'NO coincide'}");
        if (users.first['status'] != status) {
             print("[DBHelper.insertarUsuario] ADVERTENCIA CRÍTICA: El status final en DB (${users.first['status']}) es DIFERENTE del status deseado ($status) para $email.");
        }
      } else {
        print("[DBHelper.insertarUsuario] ERROR CRÍTICO: No se pudo encontrar el usuario $email después de las operaciones de insert/update.");
      }

    } catch (e, s) {
      print("[DBHelper.insertarUsuario] EXCEPCIÓN para $email: $e");
      print("[DBHelper.insertarUsuario] StackTrace: $s");
      
    }
    return resultId; 
  }

  static Future<Map<String, dynamic>?> obtenerUsuarioPorEmail(String email) async {
    final db = await database;
    print("[DBHelper.obtenerUsuarioPorEmail] Buscando usuario con email: ${email.toLowerCase().trim()}");
    final result = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    if (result.isNotEmpty) {
      print("[DBHelper.obtenerUsuarioPorEmail] Usuario encontrado: ${result.first}");
      return result.first;
    } else {
      print("[DBHelper.obtenerUsuarioPorEmail] Usuario NO encontrado.");
      return null;
    }
  }

  
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await database;
    email = email.toLowerCase().trim();
    String hashedPassword = hashPassword(password);
    print("[DBHelper.login] Intentando login local para: $email");

    final result = await db.query(
      'usuarios',
      where: 'email = ? AND contraseña = ?',
      whereArgs: [email, hashedPassword],
      limit: 1,
    );

    if (result.isNotEmpty) {
      print("[DBHelper.login] Usuario $email encontrado con contraseña coincidente. Actualizando status a 1.");
      await db.update(
        'usuarios',
        {'status': 1},
        where: 'id = ?',
        whereArgs: [result.first['id']],
      );
      final updatedUser = await obtenerUsuarioPorEmail(email);
      print("[DBHelper.login] Login local exitoso para $email. Status ahora: ${updatedUser?['status']}");
      return updatedUser;
    }
    print("[DBHelper.login] Login local fallido para $email (usuario no encontrado o contraseña incorrecta).");
    return null;
  }

  static Future<Map<String, dynamic>?> obtenerUsuarioActivo() async {
    final db = await database;
    print("[DBHelper.obtenerUsuarioActivo] Buscando usuario con status = 1.");
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'usuarios',
        where: 'status = ?',
        whereArgs: [1],
        limit: 1, // Solo debería haber uno activo
      );
      if (maps.isNotEmpty) {
        print("[DBHelper.obtenerUsuarioActivo] Usuario activo encontrado: ${maps.first['email']} (ID: ${maps.first['id']}, Status: ${maps.first['status']})");
        return maps.first;
      } else {
        print("[DBHelper.obtenerUsuarioActivo] NINGÚN usuario activo (status=1) encontrado en la BD.");
        return null;
      }
    } catch (e, s) {
      print("[DBHelper.obtenerUsuarioActivo] EXCEPCIÓN al consultar usuario activo: $e");
      print("[DBHelper.obtenerUsuarioActivo] StackTrace: $s");
      return null;
    }
  }

  static Future<void> cerrarSesion() async {
    final db = await database;
    print("[DBHelper.cerrarSesion] Iniciando cierre de sesión local.");
    
    try {
      int count = await db.update(
        'usuarios',
        {'status': 0}, // Poner a 0
        where: 'status = ?', // Solo los que estaban en 1
        whereArgs: [1],
      );
      print("[DBHelper.cerrarSesion] Filas actualizadas (usuarios con status=1 puestos a status=0): $count.");
      if (count == 0) {
          print("[DBHelper.cerrarSesion] Info: No se encontraron usuarios con status=1 para actualizar (podría ser normal si ya estaban en 0).");
      }
    } catch (e, s) {
      print("[DBHelper.cerrarSesion] EXCEPCIÓN al actualizar status a 0: $e");
      print("[DBHelper.cerrarSesion] StackTrace: $s");
    }

    // Verificación final
    final postCerrarSesionUser = await obtenerUsuarioActivo(); // Esto ya loguea su resultado
    if (postCerrarSesionUser == null) {
      print("[DBHelper.cerrarSesion] Verificación POST-cierre: NINGÚN usuario activo (status=1) encontrado. Correcto.");
    } else {
      print("[DBHelper.cerrarSesion] ADVERTENCIA CRÍTICA POST-cierre: AÚN se encontró un usuario activo: ${postCerrarSesionUser['email']} (status: ${postCerrarSesionUser['status']}). ¡Revisar lógica de UPDATE!");
    }
  }

  static Future<int> insertarProyecto({
    required int usuarioId,
    required String nombreProyecto,
    required List<dynamic> respuestas,
    String? resultadoIA,
  }) async {
    final db = await database;
    final String respuestasJson = jsonEncode(respuestas);
    final String fechaActual = DateTime.now().toIso8601String();
    print("[DBHelper.insertarProyecto] Insertando proyecto para usuario ID $usuarioId, nombre: $nombreProyecto");

    try {
      int id = await db.insert(
        'proyectos',
        {
          'usuario_id': usuarioId,
          'nombre_proyecto': nombreProyecto.trim(),
          'respuestas_json': respuestasJson,
          'resultado_ia_json': resultadoIA,
          'fecha_creacion': fechaActual,
          'fecha_modificacion': fechaActual,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("[DBHelper.insertarProyecto] Proyecto insertado con ID local: $id");
      return id;
    } catch (e, s) {
      print("[DBHelper.insertarProyecto] EXCEPCIÓN al insertar proyecto: $e");
      print("[DBHelper.insertarProyecto] StackTrace: $s");
      return -1;
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerProyectosPorUsuario(int usuarioId) async {
    final db = await database;
    print("[DBHelper.obtenerProyectosPorUsuario] Obteniendo proyectos para usuario ID: $usuarioId");
    try {
      final projects = await db.query(
        'proyectos',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy: 'fecha_modificacion DESC',
      );
      print("[DBHelper.obtenerProyectosPorUsuario] Encontrados ${projects.length} proyectos.");
      return projects;
    } catch (e, s) {
      print("[DBHelper.obtenerProyectosPorUsuario] EXCEPCIÓN: $e");
      print("[DBHelper.obtenerProyectosPorUsuario] StackTrace: $s");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> obtenerProyectoPorId(int proyectoId) async {
    final db = await database;
     print("[DBHelper.obtenerProyectoPorId] Obteniendo proyecto con ID local: $proyectoId");
    try {
      final result = await db.query(
        'proyectos',
        where: 'id = ?',
        whereArgs: [proyectoId],
        limit: 1,
      );
      if (result.isNotEmpty) {
        print("[DBHelper.obtenerProyectoPorId] Proyecto encontrado: ${result.first['nombre_proyecto']}");
        return result.first;
      } else {
        print("[DBHelper.obtenerProyectoPorId] Proyecto con ID local $proyectoId NO encontrado.");
        return null;
      }
    } catch (e,s) {
      print("[DBHelper.obtenerProyectoPorId] EXCEPCIÓN: $e");
      print("[DBHelper.obtenerProyectoPorId] StackTrace: $s");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> obtenerProyectoPorFirestoreId(String firestoreId) async {
    final db = await database;
    print("[DBHelper.obtenerProyectoPorFirestoreId] Obteniendo proyecto con Firestore ID: $firestoreId");
    try {
      final result = await db.query(
        'proyectos',
        where: 'firestore_project_id = ?',
        whereArgs: [firestoreId],
        limit: 1,
      );
       if (result.isNotEmpty) {
        print("[DBHelper.obtenerProyectoPorFirestoreId] Proyecto encontrado: ${result.first['nombre_proyecto']}");
        return result.first;
      } else {
        print("[DBHelper.obtenerProyectoPorFirestoreId] Proyecto con Firestore ID $firestoreId NO encontrado.");
        return null;
      }
    } catch (e,s) {
      print("[DBHelper.obtenerProyectoPorFirestoreId] EXCEPCIÓN: $e");
      print("[DBHelper.obtenerProyectoPorFirestoreId] StackTrace: $s");
      return null;
    }
  }

  static Future<int> actualizarProyecto({
    required int proyectoId, // ID local
    String? nombreProyecto,
    List<dynamic>? respuestas,
    String? resultadoIA,
    String? firestoreProjectId, // ID de Firestore
  }) async {
    final db = await database;
    final Map<String, dynamic> dataToUpdate = {};
    print("[DBHelper.actualizarProyecto] Actualizando proyecto con ID local: $proyectoId");

    if (nombreProyecto != null) dataToUpdate['nombre_proyecto'] = nombreProyecto.trim();
    if (respuestas != null) dataToUpdate['respuestas_json'] = jsonEncode(respuestas);
    if (resultadoIA != null) dataToUpdate['resultado_ia_json'] = resultadoIA;
    if (firestoreProjectId != null) dataToUpdate['firestore_project_id'] = firestoreProjectId;

    if (dataToUpdate.isEmpty) {
      print("[DBHelper.actualizarProyecto] No hay datos para actualizar para proyecto ID: $proyectoId");
      return 0; // No hay nada que actualizar
    }

    dataToUpdate['fecha_modificacion'] = DateTime.now().toIso8601String();
    print("[DBHelper.actualizarProyecto] Datos a actualizar para ID $proyectoId: $dataToUpdate");

    try {
      int updatedRows = await db.update(
        'proyectos',
        dataToUpdate,
        where: 'id = ?',
        whereArgs: [proyectoId],
      );
      print("[DBHelper.actualizarProyecto] Filas afectadas para proyecto ID $proyectoId: $updatedRows");
      return updatedRows;
    } catch (e,s) {
      print("[DBHelper.actualizarProyecto] EXCEPCIÓN al actualizar proyecto ID $proyectoId: $e");
      print("[DBHelper.actualizarProyecto] StackTrace: $s");
      return -1;
    }
  }

  static Future<int> eliminarProyecto(int proyectoId) async {
    final db = await database;
    print("[DBHelper.eliminarProyecto] Eliminando proyecto con ID local: $proyectoId");
    try {
      int deletedRows = await db.delete(
        'proyectos',
        where: 'id = ?',
        whereArgs: [proyectoId],
      );
      print("[DBHelper.eliminarProyecto] Filas eliminadas para proyecto ID $proyectoId: $deletedRows");
      return deletedRows;
    } catch (e,s) {
      print("[DBHelper.eliminarProyecto] EXCEPCIÓN al eliminar proyecto ID $proyectoId: $e");
      print("[DBHelper.eliminarProyecto] StackTrace: $s");
      return -1;
    }
  }

  static Future<int> eliminarProyectosPorUsuario(int usuarioId) async {
    final db = await database;
    print("[DBHelper.eliminarProyectosPorUsuario] Eliminando todos los proyectos para usuario ID: $usuarioId");
    try {
      int deletedRows = await db.delete(
        'proyectos',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
      );
      print("[DBHelper.eliminarProyectosPorUsuario] Filas eliminadas para usuario ID $usuarioId: $deletedRows");
      return deletedRows;
    } catch (e,s) {
      print("[DBHelper.eliminarProyectosPorUsuario] EXCEPCIÓN al eliminar proyectos para usuario ID $usuarioId: $e");
      print("[DBHelper.eliminarProyectosPorUsuario] StackTrace: $s");
      return -1;
    }
  }

  static Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      print("[DBHelper.close] Cerrando la conexión a la base de datos.");
      await _db!.close();
      _db = null;
    } else {
      print("[DBHelper.close] La conexión a la base de datos ya está cerrada o no fue inicializada.");
    }
  }
}