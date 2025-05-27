import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'package:runi/db.dart'; 
import 'package:runi/wizard.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    HomeContent(),
    ToolsContent(),
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
        builder: (_) => LogoStyleQuestionScreen(
          nombreEmpresa: nombreEmpresa,
          coloresSugeridos: coloresSugeridos,
          accentColor: widget.buttonColor,
          textColor: widget.textColor,
          buttonTextColor: Colors.black87,
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
        onButtonPressed: _loadUserAndProjectsFromFirestore,
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


class LogoStyleQuestionScreen extends StatelessWidget {
  final String nombreEmpresa;
  final String coloresSugeridos;
  final Color accentColor;
  final Color textColor;
  final Color buttonTextColor;

  const LogoStyleQuestionScreen({
    Key? key,
    required this.nombreEmpresa,
    required this.coloresSugeridos,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text("Estilo de Logo para ${nombreEmpresa}", style: TextStyle(color: buttonTextColor)),
        backgroundColor: accentColor,
        iconTheme: IconThemeData(color: buttonTextColor),
        ),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("Pantalla de Estilo de Logo\nNombre: $nombreEmpresa\nColores: $coloresSugeridos", style: TextStyle(color: textColor, fontSize: 18), textAlign: TextAlign.center,),
      )),
    );
  }
}


class ShowLogoPromptScreen extends StatelessWidget {
  final String prompt;
  final Color accentColor;
  final Color textColor;
  final Color buttonTextColor;

  const ShowLogoPromptScreen({
    Key? key,
    required this.prompt,
    required this.accentColor,
    required this.textColor,
    required this.buttonTextColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text("Prompt Generado", style: TextStyle(color: buttonTextColor)),
        backgroundColor: accentColor,
        iconTheme: IconThemeData(color: buttonTextColor),
        ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(child: SelectableText(prompt, style: TextStyle(color: textColor, fontSize: 16))),
      ),
    );
  }
}


class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  // final GoogleSignIn _googleSignIn = GoogleSignIn(); // No se usa aquí directamente

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
      // await _googleSignIn.signOut(); // Si usas Google Sign In, asegúrate que la instancia sea la correcta.
      await FirebaseAuth.instance.signOut();
      await DBHelper.cerrarSesion();
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