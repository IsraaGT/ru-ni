import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
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
          print("Tabla 'proyectos' creada en onUpgrade (desde v1).");
        }
        if (oldVersion < 3) {
          await db.execute('''
            ALTER TABLE proyectos ADD COLUMN firestore_project_id TEXT NULL
          ''');
          print("Columna 'firestore_project_id' añadida a 'proyectos' en onUpgrade (desde v2).");
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        print("PRAGMA foreign_keys = ON ejecutado.");
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE,
        contraseña TEXT,
        status INTEGER
      )
    ''');
    print("Tabla 'usuarios' creada en _createTables.");

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
    print("Tabla 'proyectos' creada en _createTables (con firestore_project_id).");
  }

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<int> insertarUsuario(String email, String password, {int status = 1, String? firebaseAuthUid}) async {
    final db = await database;
    Map<String, dynamic> row = {
      'email': email.toLowerCase().trim(),
      'contraseña': (password == "[GOOGLE_USER]" || password == "[APPLE_USER]") ? password : hashPassword(password),
      'status': status,
    };
    try {
      return await db.insert(
        'usuarios',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print("Error al insertar usuario: $e");
      return -1;
    }
  }

  static Future<Map<String, dynamic>?> obtenerUsuarioPorEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'email = ? AND contraseña = ?',
      whereArgs: [email.toLowerCase().trim(), hashPassword(password)],
    );
    if (result.isNotEmpty) {
      await db.update(
        'usuarios',
        {'status': 1},
        where: 'id = ?',
        whereArgs: [result.first['id']],
      );
      return result.first;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> obtenerUsuarioActivo() async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'status = ?',
      whereArgs: [1],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  static Future<void> cerrarSesion() async {
    final db = await database;
    final usuarioActivo = await obtenerUsuarioActivo();
    if (usuarioActivo != null && usuarioActivo['id'] != null) {
      await db.update(
        'usuarios',
        {'status': 0},
        where: 'id = ?',
        whereArgs: [usuarioActivo['id']],
      );
    } else {
      await db.update('usuarios', {'status': 0}, where: 'status = ?', whereArgs: [1]);
      print("Cerrando sesión de todos los usuarios con status 1.");
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

    try {
      return await db.insert(
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
    } catch (e) {
      print("Error al insertar proyecto en SQLite: $e");
      return -1;
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerProyectosPorUsuario(int usuarioId) async {
    final db = await database;
    try {
      return await db.query(
        'proyectos',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy: 'fecha_modificacion DESC',
      );
    } catch (e) {
      print("Error al obtener proyectos por usuario: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> obtenerProyectoPorId(int proyectoId) async {
    final db = await database;
    try {
      final result = await db.query(
        'proyectos',
        where: 'id = ?',
        whereArgs: [proyectoId],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print("Error al obtener proyecto por ID: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> obtenerProyectoPorFirestoreId(String firestoreId) async {
    final db = await database;
    try {
      final result = await db.query(
        'proyectos',
        where: 'firestore_project_id = ?',
        whereArgs: [firestoreId],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print("Error al obtener proyecto por firestore_project_id: $e");
      return null;
    }
  }

  static Future<int> actualizarProyecto({
    required int proyectoId,
    String? nombreProyecto,
    List<dynamic>? respuestas,
    String? resultadoIA,
    String? firestoreProjectId,
  }) async {
    final db = await database;
    final Map<String, dynamic> dataToUpdate = {};

    if (nombreProyecto != null) dataToUpdate['nombre_proyecto'] = nombreProyecto.trim();
    if (respuestas != null) dataToUpdate['respuestas_json'] = jsonEncode(respuestas);
    if (resultadoIA != null) dataToUpdate['resultado_ia_json'] = resultadoIA;
    if (firestoreProjectId != null) dataToUpdate['firestore_project_id'] = firestoreProjectId;

    if (dataToUpdate.isEmpty) return 0;

    dataToUpdate['fecha_modificacion'] = DateTime.now().toIso8601String();

    try {
      return await db.update(
        'proyectos',
        dataToUpdate,
        where: 'id = ?',
        whereArgs: [proyectoId],
      );
    } catch (e) {
      print("Error al actualizar proyecto: $e");
      return -1;
    }
  }

  static Future<int> eliminarProyecto(int proyectoId) async {
    final db = await database;
    try {
      return await db.delete(
        'proyectos',
        where: 'id = ?',
        whereArgs: [proyectoId],
      );
    } catch (e) {
      print("Error al eliminar proyecto: $e");
      return -1;
    }
  }

  static Future<int> eliminarProyectosPorUsuario(int usuarioId) async {
    final db = await database;
    try {
      return await db.delete(
        'proyectos',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
      );
    } catch (e) {
      print("Error al eliminar proyectos por usuario: $e");
      return -1;
    }
  }

  static Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
