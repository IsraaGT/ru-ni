import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para Clipboard
// import 'package:intl/intl.dart'; // No se usa directamente aquí, pero puede ser útil en otras partes
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Asegúrate que estas rutas sean correctas para tu estructura de proyecto
import 'package:runi/db.dart';
import 'package:runi/wizard.dart'; // Solo para el tipo WizardScreen
import 'package:url_launcher/url_launcher.dart'; // Para abrir URLs

// Screen principal que contiene el BottomNavigationBar y las diferentes vistas/pestañas
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    HomeContent(),
    ToolsContent(), // Esta es la pestaña "Generar Logo"
    ProfileContent(),
    SettingsContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final Color _bottomNavBackgroundColor = const Color(0xFF2C2C3A);
  final Color _bottomNavSelectedItemColor = Colors.white;
  final Color _bottomNavUnselectedItemColor = Colors.white60;

  @override
  Widget build(BuildContext context) {
    final ThemeData localTheme = Theme.of(context).copyWith();

    return Theme(
      data: localTheme,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
            BottomNavigationBarItem(icon: Icon(Icons.build), label: "Generar Logo"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ajustes"),
          ],
          currentIndex: _selectedIndex,
          backgroundColor: _bottomNavBackgroundColor,
          selectedItemColor: _bottomNavSelectedItemColor,
          unselectedItemColor: _bottomNavUnselectedItemColor,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}


class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  int? _activeUserId;
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  final Color _projectTitleColor = const Color(0xFFF4A261);
  final Color _addIconColor = const Color(0xFFF4A261);
  final Color _projectCardBackgroundColor = const Color(0xFF2C2C3A);
  final Color _addCardBackgroundColor = Colors.white12;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndProjects();
  }

  Future<void> _loadUserDataAndProjects() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final usuario = await DBHelper.obtenerUsuarioActivo();
    if (usuario != null && usuario['id'] != null) {
      final userId = usuario['id'] as int;
      final projectsFromDb = await DBHelper.obtenerProyectosPorUsuario(userId);
      if (mounted) {
        setState(() {
          _activeUserId = userId;
          _projects = projectsFromDb;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        print("HomeContent: No hay usuario activo.");
      }
    }
  }

  void _navigateToWizard({int? proyectoId}) {
    if (_activeUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WizardScreen(
            usuarioId: _activeUserId!,
            proyectoId: proyectoId,
          ),
        ),
      ).then((_) {
        _loadUserDataAndProjects();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Error: No se pudo identificar al usuario.")),
      );
    }
  }

  Future<void> _deleteProject(int projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C3A),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          contentTextStyle: TextStyle(color: Colors.white70),
          title: const Text('Confirmar Eliminación'),
          content: const Text(
              '¿Estás seguro de que quieres eliminar este proyecto? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFFF4A261))),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final result = await DBHelper.eliminarProyecto(projectId);
      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Proyecto eliminado con éxito.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green),
        );
        _loadUserDataAndProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar el proyecto.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _projectTitleColor));
    }

    final List<Widget> gridItemsWidgets = [];

    gridItemsWidgets.add(
      GestureDetector(
        onTap: () => _navigateToWizard(),
        child: Container(
          decoration: BoxDecoration(
            color: _addCardBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(Icons.add, size: 60, color: _addIconColor),
          ),
        ),
      ),
    );

    gridItemsWidgets.addAll(_projects.map((project) {
      String projectName =
          project['nombre_proyecto'] as String? ?? 'Proyecto sin nombre';
      int projectId = project['id'] as int;

      return GestureDetector(
        onTap: () => _navigateToWizard(proyectoId: projectId),
        child: Container(
          decoration: BoxDecoration(
            color: _projectCardBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    projectName,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.redAccent.withOpacity(0.7)),
                  onPressed: () => _deleteProject(projectId),
                  tooltip: 'Eliminar proyecto',
                  iconSize: 22,
                  padding: EdgeInsets.all(6),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList());

    Widget content;
    if (gridItemsWidgets.length == 1 && !_isLoading) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off_outlined, size: 60, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                "Aún no tienes proyectos",
                style: TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Toca el botón '+' para crear tu primera identidad de marca.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Crear Nuevo Proyecto"),
                  onPressed: () => _navigateToWizard(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _projectTitleColor,
                      foregroundColor: Colors.black,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12)))
            ],
          ),
        ),
      );
    } else {
      content = GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: gridItemsWidgets,
      );
    }

    return Container(
      color: const Color(0xFF1E1E2C),
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Crea tu proyecto",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _projectTitleColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// --- Contenido de la Pestaña Herramientas (Ahora "Generar Logo") ---
class ToolsContent extends StatelessWidget {
  const ToolsContent({super.key});

  final Color _accentColor = const Color(0xFFF4A261);
  final Color _textColor = Colors.white;
  final Color _backgroundColor = const Color(0xFF1E1E2C);
  final Color _cardColor = const Color(0xFF2C2C3A);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor,
      child: SelectProjectForLogoPromptScreen(
        buttonColor: _accentColor,
        textColor: _textColor,
        cardColor: _cardColor,
      ),
    );
  }
}

// --- Pantalla: SelectProjectForLogoPromptScreen (CORREGIDA) ---
class SelectProjectForLogoPromptScreen extends StatefulWidget {
  final Color buttonColor;
  final Color textColor;
  final Color cardColor;

  const SelectProjectForLogoPromptScreen({
    super.key,
    required this.buttonColor,
    required this.textColor,
    required this.cardColor,
  });

  @override
  _SelectProjectForLogoPromptScreenState createState() =>
      _SelectProjectForLogoPromptScreenState();
}

class _SelectProjectForLogoPromptScreenState
    extends State<SelectProjectForLogoPromptScreen> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String? _firebaseAuthUid;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInternetAndLoadData();
  }

  Future<void> _checkInternetAndLoadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    bool isConnected =
        await InternetConnectionChecker.createInstance().hasConnection;

    if (!mounted) return;

    if (isConnected) {
      if (!_hasInternet) {
        setState(() {
          _hasInternet = true;
        });
      }
      await _loadUserAndProjectsFromFirestore();
    } else {
      if (_hasInternet) { 
        setState(() {
          _hasInternet = false;
          _isLoading = false;
          _projects = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "No hay conexión a internet. No se pueden cargar los proyectos de la nube.",
                    style: TextStyle(color: widget.textColor)),
                backgroundColor: Colors.orangeAccent),
          );
        }
      } else { 
         setState(() {
          _isLoading = false;
          _projects = [];
        });
      }
    }
  }

  Future<void> _loadUserAndProjectsFromFirestore() async {
    if (!mounted || !_hasInternet) {
      if (!_hasInternet && _isLoading) {
        setState(() => _isLoading = false);
      }
      return;
    }
    
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _projects = [];
          _firebaseAuthUid = null;
        });
      }
      return;
    }
    _firebaseAuthUid = user.uid;

    try {
      final QuerySnapshot projectSnapshots = await FirebaseFirestore.instance
          .collection('proyectos')
          .where('firebaseAuthUid', isEqualTo: _firebaseAuthUid)
          .orderBy('fecha_modificacion', descending: true)
          .get();

      List<Map<String, dynamic>> tempProjects = [];
      for (var doc in projectSnapshots.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id_firestore'] = doc.id;

        String? nombreMarcaExtraido;
        String? paletaColoresExtraidaDelResultadoIA;
        String? paletaColoresDePreguntaWizard;

        if (data['resultado_ia_json'] is String) {
          String resultadoCompleto = data['resultado_ia_json'];
          try {
            RegExp regExpNombreMarca = RegExp(
                r"Nombre de la marca\s*\n(.*?)(?:\n\n|\n[A-ZÁÉÍÓÚÑ]|$)",
                caseSensitive: false, multiLine: true, dotAll: true);
            Match? matchNombreMarca =
                regExpNombreMarca.firstMatch(resultadoCompleto);
            if (matchNombreMarca != null && matchNombreMarca.group(1) != null) {
              nombreMarcaExtraido = matchNombreMarca.group(1)!
                  .trim().replaceAll("(Sugerencia)", "").trim();
              if (nombreMarcaExtraido.isEmpty ||
                  nombreMarcaExtraido.toLowerCase().contains("no se pudo generar") ||
                  nombreMarcaExtraido.toLowerCase().contains("no es posible sugerir")) {
                nombreMarcaExtraido = null;
              }
            }
          } catch (e) {
            print("Error parseando nombre de marca desde resultado_ia_json: $e");
          }
        }
        if (nombreMarcaExtraido == null && data['respuestas_json'] is String) {
          try {
            List<dynamic> respuestas = jsonDecode(data['respuestas_json']);
            if (respuestas.isNotEmpty && respuestas[0] is String) {
              String nombreProyectoEnRespuestas = respuestas[0].trim();
              if (nombreProyectoEnRespuestas.isNotEmpty) {
                nombreMarcaExtraido = nombreProyectoEnRespuestas;
              }
            }
          } catch (e) {
            print("Error parseando nombre de proyecto desde respuestas_json: $e");
          }
        }
        nombreMarcaExtraido ??= data['nombre_proyecto'] as String?;
        data['nombre_marca_extraido_o_proyecto'] =
            nombreMarcaExtraido ?? 'Marca Desconocida';

        if (data['resultado_ia_json'] is String) {
          String resultadoCompleto = data['resultado_ia_json'];
          try {
            RegExp regExpColoresIA = RegExp(
                r"Paleta de colores recomendada\s*\n(.*?)(?:\n\n|\n[A-ZÁÉÍÓÚÑ]|$)",
                caseSensitive: false, multiLine: true, dotAll: true);
            Match? matchColoresIA =
                regExpColoresIA.firstMatch(resultadoCompleto);
            if (matchColoresIA != null && matchColoresIA.group(1) != null) {
              paletaColoresExtraidaDelResultadoIA =
                  matchColoresIA.group(1)!.trim();
              if (paletaColoresExtraidaDelResultadoIA.isEmpty) {
                paletaColoresExtraidaDelResultadoIA = null;
              }
            }
          } catch (e) {
            print("Error parseando paleta de colores desde resultado_ia_json: $e");
          }
        }
        if (paletaColoresExtraidaDelResultadoIA == null &&
            data['respuestas_json'] is String) {
          try {
            List<dynamic> respuestas = jsonDecode(data['respuestas_json']);
            int indicePreguntaColores = 15;
            if (respuestas.length > indicePreguntaColores &&
                respuestas[indicePreguntaColores] != null) {
              String respuestaColorWizard =
                  respuestas[indicePreguntaColores].toString();
              if (respuestaColorWizard.isNotEmpty) {
                if (respuestaColorWizard.startsWith('Otro: ')) {
                  paletaColoresDePreguntaWizard =
                      respuestaColorWizard.substring('Otro: '.length).trim();
                } else {
                  paletaColoresDePreguntaWizard = respuestaColorWizard.trim();
                }
                if (paletaColoresDePreguntaWizard.isEmpty) {
                  paletaColoresDePreguntaWizard = null;
                }
              }
            }
          } catch (e) {
            print("Error decodificando respuestas_json o accediendo al índice de colores: $e");
          }
        }
        data['paleta_colores_final'] =
            paletaColoresExtraidaDelResultadoIA ?? paletaColoresDePreguntaWizard;
        tempProjects.add(data);
      }

      if (mounted) {
        setState(() {
          _projects = tempProjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error al cargar proyectos: ${e.toString()}",
                  style: TextStyle(color: widget.textColor)),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _onProjectSelected(Map<String, dynamic> projectData) {
    String nombreEmpresa = projectData['nombre_marca_extraido_o_proyecto'] as String;
    String coloresSugeridos =
        projectData['paleta_colores_final'] as String? ?? "colores vibrantes y modernos";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogoConfigurationScreen(
          nombreEmpresa: nombreEmpresa,
          coloresSugeridos: coloresSugeridos,
          accentColor: widget.buttonColor,
          textColor: widget.textColor,
          buttonTextColor: Colors.black87, // O el color que prefieras para el texto de los botones/chips seleccionados
        ),
      ),
    );
  }

  Widget _buildCenteredMessageWithButton(
      {required IconData iconData,
      required String message,
      String? subMessage,
      required VoidCallback onButtonPressed,
      required String buttonText}) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 60, color: widget.textColor.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor.withOpacity(0.9)),
                textAlign: TextAlign.center,
              ),
              if (subMessage != null && subMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subMessage,
                  style: TextStyle(
                      fontSize: 15, color: widget.textColor.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh, color: Colors.black87),
                label: Text(buttonText, style: TextStyle(color: Colors.black87)),
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(backgroundColor: widget.buttonColor, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isLoading) {
      bodyContent = Expanded(
          child: Center(child: CircularProgressIndicator(color: widget.buttonColor)));
    } else if (!_hasInternet) {
      bodyContent = _buildCenteredMessageWithButton(
        iconData: Icons.wifi_off_rounded,
        message: "Sin conexión a Internet",
        subMessage: "Necesitas conexión a internet para cargar tus proyectos de la nube y usar esta herramienta.",
        onButtonPressed: _checkInternetAndLoadData,
        buttonText: "Reintentar Conexión"
      );
    } else if (_firebaseAuthUid == null) { 
        bodyContent = _buildCenteredMessageWithButton(
        iconData: Icons.login_rounded,
        message: "Debes iniciar sesión",
        subMessage: "Inicia sesión desde la pestaña de Perfil para acceder a tus proyectos en la nube.",
        onButtonPressed: () {
             _checkInternetAndLoadData();
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Por favor, ve a la pestaña 'Perfil' para iniciar sesión.",
                      style: TextStyle(color: widget.textColor)),
                  backgroundColor: widget.buttonColor.withOpacity(0.8)),
            );
        },
        buttonText: "Comprobar Sesión"
      );
    }
     else if (_projects.isEmpty) { 
      bodyContent = _buildCenteredMessageWithButton(
        iconData: Icons.cloud_off_rounded,
        message: "No tienes proyectos en la nube",
        subMessage: "Crea un proyecto y genera su identidad de marca para verlo aquí, o asegúrate que tus proyectos existentes tengan la información necesaria.",
        onButtonPressed: _checkInternetAndLoadData,
        buttonText: "Recargar Proyectos"
      );
    }
     else { 
      bodyContent = Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _projects.length,
          itemBuilder: (context, index) {
            final project = _projects[index];
            String displayName = project['nombre_marca_extraido_o_proyecto'] as String;
            String coloresInfo = project['paleta_colores_final'] != null
                ? "Colores: ${project['paleta_colores_final']}"
                : "Colores base: No especificados";

            if (project['paleta_colores_final'] != null &&
                (project['paleta_colores_final'] as String).length > 30) {
              coloresInfo = "Colores: ${(project['paleta_colores_final'] as String).substring(0, 27)}...";
            }

            return Card(
              color: widget.cardColor,
              margin: const EdgeInsets.symmetric(vertical: 7),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                leading: CircleAvatar(
                  backgroundColor: widget.buttonColor.withOpacity(0.2),
                  child: Icon(Icons.style_outlined, color: widget.buttonColor, size: 24),
                ),
                title: Text(
                  displayName,
                  style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w600, fontSize: 17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(coloresInfo, style: TextStyle(color: widget.textColor.withOpacity(0.7), fontSize: 13)),
                trailing: Icon(Icons.chevron_right, color: widget.textColor.withOpacity(0.7)),
                onTap: () => _onProjectSelected(project),
              ),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 0, left: 16, right: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "Generar Prompt para Logo",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor),
                ),
              ),
              if (!_isLoading && _hasInternet && _firebaseAuthUid != null)
                Tooltip(
                  message: "Recargar lista de proyectos",
                  child: IconButton(
                    icon: Icon(Icons.refresh_rounded, color: widget.textColor.withOpacity(0.8), size: 26,),
                    onPressed: _loadUserAndProjectsFromFirestore, 
                    padding: EdgeInsets.all(12),
                    splashRadius: 24,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Selecciona un proyecto de la nube para extraer su nombre de marca y colores base.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: widget.textColor.withOpacity(0.8)),
          ),
        ),
        bodyContent,
      ],
    );
  }
}


// --- Pantalla: LogoConfigurationScreen (NUEVA) ---
class LogoConfigurationScreen extends StatefulWidget {
  final String nombreEmpresa;
  final String coloresSugeridos;
  final Color accentColor;
  final Color textColor;
  final Color buttonTextColor;

  const LogoConfigurationScreen({
    Key? key,
    required this.nombreEmpresa,
    required this.coloresSugeridos,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
  }) : super(key: key);

  @override
  _LogoConfigurationScreenState createState() => _LogoConfigurationScreenState();
}

class _LogoConfigurationScreenState extends State<LogoConfigurationScreen> {
  // Opciones
  final List<String> _estilosPrincipales = [
    "Minimalista", "Moderno", "Abstracto", "Geométrico", "Orgánico",
    "Vintage/Retro", "Ilustrativo", "Tipográfico", "Emblema", "Isométrico",
    "Estilo Neón", "Diseño Plano (Flat)", "Arte Lineal (Line Art)",
    "Acuarela Digital", "Tecnológico", "Juguetón"
  ];
  String? _selectedEstiloPrincipal;

  final List<String> _tiposDeLogo = [
    "Nominativo", "No nominativo", "Combinado/Mixto"
  ];
  String? _selectedTipoDeLogo;

  final List<String> _formasPredominantes = [
    "Circular", "Cuadrado", "Triangular", "Rectangular", "Ovalado",
    "Formas Libres/Orgánicas", "Lineal", "Basado en Escudo/Emblema", "Hexagonal"
  ];
  final Set<String> _selectedFormas = {};

  final TextEditingController _conceptosAdicionalesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedEstiloPrincipal = _estilosPrincipales.first; // Valor por defecto
    _selectedTipoDeLogo = _tiposDeLogo.first; // Valor por defecto
  }

  @override
  void dispose() {
    _conceptosAdicionalesController.dispose();
    super.dispose();
  }

  void _generarPrompt() {
    if (_selectedEstiloPrincipal == null) {
      _showErrorSnackBar("Por favor, elige un estilo principal.");
      return;
    }
    if (_selectedTipoDeLogo == null) {
      _showErrorSnackBar("Por favor, selecciona un tipo de logo.");
      return;
    }

    String prompt = "Crear un logo para la marca \"${widget.nombreEmpresa}\".\n\n";
    prompt += "Estilo principal: $_selectedEstiloPrincipal.\n";
    prompt += "Tipo de logo: $_selectedTipoDeLogo.\n";

    if (_selectedFormas.isNotEmpty) {
      prompt += "Formas predominantes: ${_selectedFormas.join(', ')}.\n";
    } else {
      prompt += "Formas predominantes: Elige las más adecuadas según el estilo y concepto.\n";
    }

    prompt += "Colores base sugeridos: ${widget.coloresSugeridos}.\n";

    if (_conceptosAdicionalesController.text.trim().isNotEmpty) {
      prompt += "Elementos o conceptos adicionales a incorporar: ${_conceptosAdicionalesController.text.trim()}.\n";
    }

    prompt += "\nConsideraciones importantes según el tipo de logo:\n";
    if (_selectedTipoDeLogo == "Nominativo") {
      prompt += "- El nombre de la marca \"${widget.nombreEmpresa}\" debe ser el elemento central y legible del logo. Puede incluir elementos gráficos sutiles de apoyo.\n";
    } else if (_selectedTipoDeLogo == "No nominativo") {
      prompt += "- Crear un isotipo o símbolo distintivo que represente la marca sin incluir el nombre \"${widget.nombreEmpresa}\". El diseño debe ser memorable y escalable.\n";
    } else if (_selectedTipoDeLogo == "Combinado/Mixto") {
      prompt += "- Diseñar un logo que integre tanto el nombre de la marca \"${widget.nombreEmpresa}\" como un isotipo/símbolo. Ambos elementos deben poder funcionar juntos y, opcionalmente, por separado.\n";
    }

    prompt += "\nEl resultado debe ser un diseño de logo profesional, adecuado para la identidad de marca descrita. Presentar el logo sobre un fondo blanco o neutro para una clara visualización.";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowLogoPromptScreen(
          prompt: prompt,
          accentColor: widget.accentColor,
          textColor: widget.textColor,
          buttonTextColor: widget.buttonTextColor,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
            color: widget.textColor, fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChoiceChipGroup<T>(
      String title, List<T> items, T? selectedItem, ValueChanged<T?> onChanged,
      {bool allowMultiple = false, Set<T>? multipleSelectedItems, ValueChanged<T>? onMultipleChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: items.map((item) {
            final bool isSelected;
            if (allowMultiple) {
              isSelected = multipleSelectedItems?.contains(item) ?? false;
            } else {
              isSelected = selectedItem == item;
            }
            return ChoiceChip(
              label: Text(item.toString()),
              selected: isSelected,
              onSelected: (selected) {
                if (allowMultiple && onMultipleChanged != null) {
                  onMultipleChanged(item); 
                } else {
                  onChanged(selected ? item : null);
                }
              },
              backgroundColor: const Color(0xFF2C2C3A), 
              selectedColor: widget.accentColor, 
              labelStyle: TextStyle(color: isSelected ? widget.buttonTextColor : widget.textColor.withOpacity(0.9), fontSize: 14),
              checkmarkColor: widget.buttonTextColor,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: BorderSide(
                  color: isSelected ? widget.accentColor : Colors.grey.shade700,
                  width: 1,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarTextColor = widget.buttonTextColor; 
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text("Configurar Logo", style: TextStyle(color: appBarTextColor)),
        backgroundColor: widget.accentColor,
        iconTheme: IconThemeData(color: appBarTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Padding(
              padding: const EdgeInsets.only(bottom: 4.0, top: 4.0),
              child: Text(
                "Marca: ${widget.nombreEmpresa}",
                style: TextStyle(
                    color: widget.textColor.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                "Colores base: ${widget.coloresSugeridos}",
                style: TextStyle(
                    color: widget.textColor.withOpacity(0.7), fontSize: 14),
              ),
            ),
            Divider(color: widget.textColor.withOpacity(0.2)),

            _buildChoiceChipGroup<String>(
              "1. Elige el estilo principal:",
              _estilosPrincipales,
              _selectedEstiloPrincipal,
              (value) => setState(() => _selectedEstiloPrincipal = value),
            ),

            _buildChoiceChipGroup<String>(
              "2. Selecciona el tipo de logo:",
              _tiposDeLogo,
              _selectedTipoDeLogo,
              (value) => setState(() => _selectedTipoDeLogo = value),
            ),

            _buildChoiceChipGroup<String>(
              "3. Elige formas predominantes (puedes seleccionar más de uno):",
              _formasPredominantes,
              null, 
              (value){}, 
              allowMultiple: true,
              multipleSelectedItems: _selectedFormas,
              onMultipleChanged: (forma) {
                setState(() {
                  if (_selectedFormas.contains(forma)) {
                    _selectedFormas.remove(forma);
                  } else {
                    _selectedFormas.add(forma);
                  }
                });
              }
            ),

            _buildSectionTitle("4. Elementos o conceptos adicionales (opcional):"),
            TextField(
              controller: _conceptosAdicionalesController,
              style: TextStyle(color: widget.textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Ej: 'un águila estilizada', 'símbolo de infinito', 'conexión y tecnología', 'naturaleza y crecimiento'",
                hintStyle: TextStyle(color: widget.textColor.withOpacity(0.5), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF2C2C3A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.auto_awesome, color: widget.buttonTextColor),
                label: Text("Generar Prompt", style: TextStyle(color: widget.buttonTextColor, fontSize: 16)),
                onPressed: _generarPrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- Pantalla: ShowLogoPromptScreen (MODIFICADA) ---
class ShowLogoPromptScreen extends StatelessWidget {
  final String prompt;
  final Color accentColor;
  final Color textColor;
  final Color buttonTextColor; // Este será el color del texto del botón de copiar

  const ShowLogoPromptScreen({
    Key? key,
    required this.prompt,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
  }) : super(key: key);

  final List<Map<String, String>> _iaTools = const [
    {'name': 'Microsoft Copilot (DALL·E 3)', 'url': 'https://copilot.microsoft.com/'},
    {'name': 'Looka AI Logo Maker', 'url': 'https://looka.com/logo-maker/'},
    {'name': 'Canva AI Logo Maker', 'url': 'https://www.canva.com/ai-logo-maker/'},
    {'name': 'Ideogram.ai', 'url': 'https://ideogram.ai/'},
    {'name': 'Adobe Firefly', 'url': 'https://firefly.adobe.com/'},
    {'name': 'Leonardo.Ai', 'url': 'https://leonardo.ai/'},
    {'name': 'Bing Image Creator', 'url': 'https://www.bing.com/images/create'},
  ];

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $urlString');
      // Consider showing a SnackBar to the user
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('No se pudo abrir $urlString', style: TextStyle(color: textColor)), backgroundColor: Colors.redAccent),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarTextColor = buttonTextColor;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text("Prompt para Logo", style: TextStyle(color: appBarTextColor)),
        backgroundColor: accentColor,
        iconTheme: IconThemeData(color: appBarTextColor),
        // Se elimina el IconButton de copiar de aquí
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Para que el botón ocupe el ancho
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withOpacity(0.7))
              ),
              child: Text(
                "IMPORTANTE: SE PONE EL NOMBRE DEL PROYECTO COMO MARCA. DE SER NECESARIO CAMBIALO AL PEGAR EL PROMPT EN UNA DE LAS PÁGINAS SUGERIDAS.",
                style: TextStyle(
                    color: accentColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C3A),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: SelectableText(
                prompt,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 16), // Espacio entre el prompt y el botón
            ElevatedButton.icon(
              icon: Icon(Icons.copy_all_outlined, color: buttonTextColor),
              label: Text("Copiar Prompt", style: TextStyle(color: buttonTextColor, fontSize: 16)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prompt));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Prompt copiado al portapapeles", style: TextStyle(color: textColor)), // Usamos textColor general para el mensaje
                      backgroundColor: Colors.green.shade700.withOpacity(0.9),
                      behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Plataformas de IA Recomendadas:",
              style: TextStyle(
                  color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _iaTools.length,
              itemBuilder: (context, index) {
                final tool = _iaTools[index];
                return Card(
                  color: const Color(0xFF2C2C3A),
                  margin: const EdgeInsets.symmetric(vertical: 5.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accentColor.withOpacity(0.15),
                      child: Icon(Icons.auto_fix_high,
                          color: accentColor, size: 22),
                    ),
                    title: Text(tool['name']!, style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 15)),
                    trailing: Icon(Icons.open_in_new_rounded, color: textColor.withOpacity(0.7), size: 20),
                    onTap: () => _launchURL(tool['url']!),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}


// --- Clases ProfileContent, SettingsContent, SettingsDetailPage ---
class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final Color _profileCardColor = Colors.white24;
  final Color _profileTextColor = Colors.white;
  final Color _profileEmailColor = Colors.white70;
  final Color _profileIconBackgroundColor = Colors.blueGrey.shade100;
  final Color _profileIconColor = Colors.blueGrey;
  final Color _logoutButtonColor = Colors.redAccent;
  final Color _profileBackgroundColor = const Color(0xFF1E1E2C);
  final Color _appAccentColor = const Color(0xFFF4A261); 

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final usuario = await DBHelper.obtenerUsuarioActivo();
    if (mounted) {
      setState(() {
        _currentUser = usuario;
        _isLoading = false;
      });
    }
  }

  void _logout(BuildContext context) async {
    try {
      await _googleSignIn.signOut();
      print("Intento de cierre de sesión de GoogleSignIn completado.");
      await FirebaseAuth.instance.signOut();
      print("Sesión de Firebase Auth cerrada.");
      await DBHelper.cerrarSesion();
      print("Sesión local de DBHelper cerrada.");
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (Route<dynamic> route) => false);
      }
    } catch (e) {
      print("Error al cerrar sesión: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al cerrar sesión: ${e.toString()}", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _profileBackgroundColor,
        child: Center(child: CircularProgressIndicator(color: _appAccentColor)),
      );
    }

    if (_currentUser == null) {
      return Container(
        color: _profileBackgroundColor,
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 60, color: _profileEmailColor),
              const SizedBox(height: 16),
              Text(
                "No hay sesión activa o no se pudo cargar la información del usuario.",
                style: TextStyle(color: _profileTextColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _logout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _appAccentColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text("Ir a Inicio de Sesión"),
              )
            ],
          ),
        ),
      );
    }

    String email = _currentUser!['email'] as String? ?? 'No disponible';

    return Container(
      color: _profileBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            color: _profileCardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: _profileIconBackgroundColor,
                    child: Icon(Icons.person, size: 70, color: _profileIconColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Mi Perfil", 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _profileTextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email, 
                    style: TextStyle(fontSize: 18, color: _profileEmailColor),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: _appAccentColor.withOpacity(0.3), thickness: 1),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text("Cerrar sesión", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _logoutButtonColor,
                      minimumSize: const Size(200, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  final Color _settingsIconColor = Colors.white;
  final Color _settingsTextColor = Colors.white;
  final Color _settingsBackgroundColor = const Color(0xFF1E1E2C);
  final Color _accentColor = const Color(0xFFF4A261); 

  void _navigateToDetailPage(BuildContext context, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsDetailPage(title: title, content: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _settingsBackgroundColor,
      child: ListView( 
        padding: const EdgeInsets.all(20.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                Icon(Icons.settings_outlined, size: 70, color: _settingsIconColor),
                const SizedBox(height: 16),
                Text(
                  "Configuración",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _settingsTextColor),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline,
            title: "Sobre Nosotros",
            onTap: () {
              _navigateToDetailPage(
                context,
                "Sobre Nosotros",
                "En nuestra empresa entendemos el gran reto que enfrentan muchas pequeñas y medianas empresas (pymes): la falta de una identidad de marca bien definida, lo que limita su presencia y crecimiento en el mercado.\n\n"
                "Por eso, hemos creado una aplicación innovadora diseñada específicamente para ayudar a las pymes a construir y fortalecer su identidad de marca. Nuestro asistente digital guía a los usuarios a través de una serie de preguntas simples y efectivas, proporcionando una estructura clara y fácil de seguir para crear su propia identidad de marca desde cero.\n\n"
                "Creemos que toda empresa, sin importar su tamaño, merece destacar y ser reconocida. Nuestra misión es empoderar a las pymes para que puedan proyectar su esencia, conectar mejor con sus clientes y alcanzar nuevas oportunidades de negocio.\n\n"
                "¡Con nosotros, tu marca toma forma y crece contigo!",
              );
            },
            iconColor: _accentColor,
            textColor: _settingsTextColor,
          ),

          _buildSettingsItem(
            context,
            icon: Icons.article_outlined,
            title: "Términos y Condiciones",
            onTap: () {
              _navigateToDetailPage(
                context,
                "Términos y Condiciones de Uso",
                "1. Aceptación de los Términos\n"
                "Al utilizar nuestra aplicación, el usuario acepta estos Términos y Condiciones en su totalidad. Si no está de acuerdo con alguna parte de los mismos, le recomendamos no utilizar la aplicación.\n\n"
                "2. Descripción del Servicio\n"
                "Nuestra aplicación ofrece una herramienta asistida para ayudar a pequeñas y medianas empresas (pymes) a crear y definir su identidad de marca mediante una serie de preguntas y recomendaciones.\n\n"
                "3. Responsabilidad\n"
                "La información, sugerencias y estructuras proporcionadas por la aplicación tienen carácter orientativo y no constituyen asesoría profesional personalizada.\n"
                "No nos hacemos responsables por errores, omisiones, resultados inesperados, o cualquier daño directo o indirecto derivado del uso, mal uso o interpretación de la información generada por la aplicación.\n"
                "El usuario es responsable de verificar y adaptar cualquier contenido sugerido antes de implementarlo en su empresa o marca.\n\n"
                "4. Uso Adecuado\n"
                "El usuario se compromete a utilizar la aplicación de manera responsable y conforme a la legislación vigente. Queda prohibido el uso de la aplicación para fines ilícitos, fraudulentos o que puedan causar perjuicio a terceros.\n\n"
                "5. Modificaciones\n"
                "Nos reservamos el derecho de modificar estos Términos y Condiciones en cualquier momento. Las modificaciones serán publicadas en la aplicación y entrarán en vigor desde su publicación.\n\n"
                "6. Contacto\n"
                "Para cualquier duda o consulta sobre estos Términos y Condiciones, puedes contactarnos a través de los canales oficiales de la empresa.",
              );
            },
            iconColor: _accentColor,
            textColor: _settingsTextColor,
          ),
          
          const SizedBox(height: 30),
          Text(
            "Más opciones próximamente...",
            textAlign: TextAlign.center,
            style: TextStyle(color: _settingsTextColor.withOpacity(0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
    required Color textColor,
  }) {
    return Card(
      color: const Color(0xFF2C2C3A), 
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 26),
        title: Text(title, style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: textColor.withOpacity(0.7)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),
    );
  }
}

class SettingsDetailPage extends StatelessWidget {
  final String title;
  final String content;

  const SettingsDetailPage({
    super.key,
    required this.title,
    required this.content,
  });

  final Color _appBarColor = const Color(0xFFF4A261);
  final Color _appBarTextColor = Colors.black87; 
  final Color _backgroundColor = const Color(0xFF1E1E2C);
  final Color _textColor = Colors.white;
  final Color _contentBoxColor = const Color(0xFF2C2C3A);


  @override
  Widget build(BuildContext context) {
    List<String> paragraphs = content.split('\n\n');

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: _appBarTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: _appBarColor,
        iconTheme: IconThemeData(color: _appBarTextColor), 
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _contentBoxColor,
                borderRadius: BorderRadius.circular(10),
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: paragraphs.map((paragraph) {
              bool isNumberedTitle = RegExp(r"^\d+\.\s+").hasMatch(paragraph);
              String textToShow = paragraph;
              String? titlePart;

              if (isNumberedTitle) {
                  int firstNewline = paragraph.indexOf('\n');
                  if (firstNewline != -1) {
                      titlePart = paragraph.substring(0, firstNewline);
                      textToShow = paragraph.substring(firstNewline + 1).trimLeft();
                  } else {
                      titlePart = paragraph;
                      textToShow = ""; 
                  }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titlePart != null)
                      Text(
                        titlePart,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          height: 1.4,
                        ),
                      ),
                    if (textToShow.isNotEmpty)
                      Text(
                        textToShow,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textColor.withOpacity(0.85),
                          height: 1.6, 
                        ),
                      ),
                  ],
                )
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}