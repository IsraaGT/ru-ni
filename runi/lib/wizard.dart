import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gemini_service.dart'; // Asegúrate de que este archivo exista y esté configurado
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'db.dart'; // Asegúrate de que este archivo exista y esté configurado
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class WizardScreen extends StatefulWidget {
  final int usuarioId; // ID del usuario local de SQLite
  final int? proyectoId; // ID del proyecto local de SQLite si se está editando

  const WizardScreen({
    Key? key,
    required this.usuarioId,
    this.proyectoId,
  }) : super(key: key);

  @override
  _WizardScreenState createState() => _WizardScreenState();
}

class ResultadoScreen extends StatelessWidget {
  final String resultado;
  final Future<void> Function(BuildContext) onExportarPdf;
  final VoidCallback onVolverAlInicio;

  const ResultadoScreen({
    required this.resultado,
    required this.onExportarPdf,
    required this.onVolverAlInicio,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Identidad de Marca Generada'),
          backgroundColor: Color(0xFFF4A261)),
      backgroundColor: Color(0xFF1E1E2C),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF2C2C3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      resultado,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onExportarPdf(context),
                icon: Icon(Icons.picture_as_pdf, color: Colors.black87),
                label: Text("Exportar a PDF", style: TextStyle(color: Colors.black87)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF4A261),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onVolverAlInicio,
                child: Text("Volver al inicio", style: TextStyle(color: Color(0xFFF4A261))),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _WizardScreenState extends State<WizardScreen> {
final GeminiService _geminiService = GeminiService(
  apiKey: dotenv.get('API_KEY', fallback: ''), 
);
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': '¿Cuál es el nombre de este proyecto de branding? (Para una mejor experiencia usa el mismo nombre de tu empresa o marca.)',
      'type': 'project_name_text',
    },
    {
      'question': '¿Tu empresa tiene nombre?',
      'type': 'choice',
      'options': ['Sí', 'No'],
    },
    {
      'question': '¿Cuál es el giro de tu negocio?',
      'type': 'choice',
      'options': ['Comercial', 'Industrial', 'Servicios', 'No estoy seguro'],
    },
    {
      'question': 'Describa brevemente a qué se dedica su empresa.',
      'type': 'text_long', // Nuevo tipo para identificar y usar un controller específico
    },
    {
      'question': '¿De qué tamaño consideras que es tu empresa?',
      'type': 'choice',
      'options': ['Micro (1-10 empleados)', 'Pequeña (11-50 empleados)', 'Mediana (51-250 empleados)', 'Grande (Más de 250 empleados)', 'Aún no lo defino'],
    },
    {
      'question': '¿Por qué existe tu empresa?',
      'type': 'choice',
      'options': [
        'Detecté una oportunidad en el mercado',
        'Seguir una pasión personal',
        'Emprender y ser independiente',
        'Continuar un legado familiar',
        'Otro'
      ],
    },
    {
      'question': '¿Qué te motivó a crearla?',
      'type': 'choice',
      'options': [
        'Generar impacto social',
        'Lograr estabilidad financiera',
        'Innovar en el sector',
        'Desarrollar un proyecto propio',
        'Otro'
      ],
    },
    {
      'question': '¿Qué problema resuelve tu empresa en el mercado?',
      'type': 'choice',
      'options': [
        'Falta de calidad',
        'Precios elevados',
        'Servicio lento o deficiente',
        'Poca innovación',
        'Otro'
      ],
    },
    { 
      'question': '¿Quiénes son tus clientes ideales?',
      'type': 'tiered_choice',
      'id': 'clientes_ideales',
      'main_question_text': 'Principalmente, ¿a quién va dirigida tu empresa?',
      'main_options': ['Personas', 'Empresas'],
      'sub_options_map': {
        'Personas': ['Niños', 'Jóvenes (18-30 años)', 'Adultos (31-50 años)', 'Personas de la tercera edad', 'Otro'],
        'Empresas': ['Micro', 'Pequeñas', 'Medianas', 'Grandes', 'Todas', 'Otro'],
      },
    },
    { 
      'question': '¿Dónde se ubican tus clientes ideales?',
      'type': 'choice',
      'options': ['Local', 'Regional', 'Nacional', 'Internacional', 'Otro'],
    },
    { 
      'question': '¿Cuáles son los intereses de tus clientes ideales?',
      'type': 'choice',
      'options': [
        'Tecnología',
        'Bienestar',
        'Educación',
        'Entretenimiento',
        'Otro'
      ],
    },
    { 
      'question': '¿Qué necesidades tienen tus clientes ideales?',
      'type': 'choice',
      'options': [
        'Ahorro de tiempo',
        'Mejor calidad',
        'Asesoría personalizada',
        'Acceso a innovación',
        'Otro'
      ],
    },
    { 
      'question': '¿Cómo quieres que tu marca se perciba visualmente?',
      'type': 'choice',
      'options': [
        'Profesional',
        'Divertida',
        'Tecnológica',
        'Elegante',
        'Amigable',
        'Otro'
      ],
    },
    { 
      'question': '¿Qué valores fundamentales guían las decisiones y acciones de tu empresa?',
      'type': 'choice',
      'options': [
        'Honestidad',
        'Innovación',
        'Compromiso',
        'Sostenibilidad',
        'Calidad',
        'Otro'
      ],
    },
    { 
      'question': 'Si tu marca fuera una persona, ¿cómo hablaría?',
      'type': 'choice',
      'options': [
        'Formal',
        'Amigable',
        'Profesional',
        'Juvenil',
        'Creativa',
        'Otro'
      ],
    },
    { 
      'question': '¿Que tipo de paleta de colores te gustaria que tuviera tu empresa?',
      'type': 'choice',
      'options': [
        'Vividos',
        'Fríos',
        'Calidos',
        'Naturales',
        'Otro'
      ],
    },
    { 
      'question': '¿Que tipo de tipografías te gustaria que tuviera tu empresa?',
      'type': 'choice',
      'options': [
        'Modernas / Sans Serif',
        'Serif ',
        'Manuscritas / Script',
        'Display / Decorativas',
        'Otro'
      ],
    },
    { 
      'question': '¿Qué estilo de diseño prefieres?',
      'type': 'choice',
      'options': [
        'Minimalista',
        'Moderno ',
        'Colorido',
        'Futurista',
        'Otro'
      ],
    },
    { 
      'question': 'De esas marcas que admiras, ¿qué te gusta de su forma de comunicar y conectar con la gente?',
      'type': 'choice',
      'options': [
        'Lenguaje claro',
        'Mensajes inspiradores',
        'Humor',
        'Comunicación visual',
        'Otro'
      ],
    },
    { 
      'question': '¿Cómo imaginas tu empresa a futuro?',
      'type': 'choice',
      'options': [
        'Líder en el mercado local',
        'Expansión nacional',
        'Internacionalización',
        'Innovadora en su sector',
        'Otro'
      ],
    },
    { 
      'question': '¿Qué impacto quieres que tenga tu empresa en la industria?',
      'type': 'choice',
      'options': [
        'Ser referente de calidad',
        'Impulsar la innovación',
        'Mejorar la competencia',
        'Fomentar la sostenibilidad',
        'Otro'
      ],
    },
  ];

  int _currentPage = 0;
  List<dynamic> _answers = [];
  String resultadoIA = "";

  final TextEditingController _nombreProyectoController = TextEditingController(text: "proyecto01");
  final TextEditingController _nombreEmpresaController = TextEditingController();
  final TextEditingController _descripcionEmpresaController = TextEditingController(); // Nuevo controller
  List<TextEditingController> _otrosControllers = [];

  String? _selectedMainAudienceOption;
  String? _selectedSubAudienceOption;

  int? _currentSqliteProjectId;
  String? _currentFirestoreProjectId;
  bool _isLoadingProject = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(_questions.length, null);
    _otrosControllers = List.generate(_questions.length, (index) => TextEditingController());
    _currentSqliteProjectId = widget.proyectoId;

    if (_currentSqliteProjectId != null) {
      _loadProjectFromSqlite(_currentSqliteProjectId!);
    } else {
      if (_answers.isNotEmpty) _answers[0] = _nombreProyectoController.text; // Asegurar que _answers tenga tamaño
      _prepareUIDataForCurrentPage();
    }
  }

  void _prepareUIDataForCurrentPage() {
    _selectedMainAudienceOption = null;
    _selectedSubAudienceOption = null;

    if (_answers.isEmpty || _currentPage >= _answers.length || _currentPage >= _questions.length) {
      return;
    }

    final currentQuestionConfig = _questions[_currentPage];
    final dynamic currentAnswer = _answers[_currentPage];

    if (currentQuestionConfig['type'] == 'tiered_choice' && currentAnswer is String) {
      final parts = currentAnswer.split(': ');
      if (parts.isNotEmpty) {
        _selectedMainAudienceOption = parts[0];
        if (!(currentQuestionConfig['main_options'] as List<String>).contains(_selectedMainAudienceOption)) {
            _selectedMainAudienceOption = null; 
        }
      }
      if (parts.length > 1 && _selectedMainAudienceOption != null) {
        _selectedSubAudienceOption = parts[1];
        List<String> validSubOptions = (currentQuestionConfig['sub_options_map'][_selectedMainAudienceOption] as List<String>? ?? []);
        if (!validSubOptions.contains(_selectedSubAudienceOption)) {
            if (_selectedSubAudienceOption != 'Otro') {
                 _selectedSubAudienceOption = null; 
            }
        }
      }
    }
  }

  Future<void> _loadProjectFromSqlite(int sqliteProjectId) async {
    setState(() => _isLoadingProject = true);
    try {
      final projectData = await DBHelper.obtenerProyectoPorId(sqliteProjectId);
      if (mounted && projectData != null) {
        _currentFirestoreProjectId = projectData['firestore_project_id'] as String?;
        
        List<dynamic> savedCombinedAnswers = [];
        if (projectData['respuestas_json'] != null) {
          savedCombinedAnswers = jsonDecode(projectData['respuestas_json']);
          
          // --- AJUSTE PARA COMPATIBILIDAD CON PROYECTOS ANTIGUOS ---
          // Esta lógica ajusta los datos de proyectos guardados antes de la adición de la pregunta
          // de "descripción de la empresa", para mantener la alineación con la estructura actual de preguntas.
          const int nuevoIndiceDescripcionEmpresa = 3; // Índice de la nueva pregunta en _questions
          // Si el formato guardado es el "viejo" (antes de añadir la pregunta de descripción)
          // y _questions ya tiene la nueva pregunta.
          // El tamaño de _questions actual es X, el viejo era X-1.
          if (savedCombinedAnswers.isNotEmpty &&
              savedCombinedAnswers.length == (_questions.length - 1) &&
              _questions.length > nuevoIndiceDescripcionEmpresa &&
              _questions[nuevoIndiceDescripcionEmpresa]['type'] == 'text_long') {
            
            // Insertar null en la posición de la nueva pregunta para alinear con _questions
            if (savedCombinedAnswers.length >= nuevoIndiceDescripcionEmpresa) {
              savedCombinedAnswers.insert(nuevoIndiceDescripcionEmpresa, null);
            } else { // Rellenar si es necesario (caso improbable)
              while(savedCombinedAnswers.length < nuevoIndiceDescripcionEmpresa) {
                savedCombinedAnswers.add(null);
              }
              savedCombinedAnswers.add(null);
            }
          }
          // --- FIN AJUSTE ---
        }

        List<dynamic> baseAnswers = List.filled(_questions.length, null); 

        _nombreProyectoController.text = savedCombinedAnswers.isNotEmpty && savedCombinedAnswers[0] != null
            ? savedCombinedAnswers[0].toString()
            : "proyecto01";
        if (baseAnswers.isNotEmpty) baseAnswers[0] = _nombreProyectoController.text;

        if (savedCombinedAnswers.length > 1 && savedCombinedAnswers[1] != null) {
          if (savedCombinedAnswers[1] is String) {
            String answer1 = savedCombinedAnswers[1] as String;
            if (answer1.startsWith('Sí: ')) {
              if (baseAnswers.length > 1) baseAnswers[1] = 'Sí';
              _nombreEmpresaController.text = answer1.substring('Sí: '.length);
            } else { if (baseAnswers.length > 1) baseAnswers[1] = answer1; }
          } else { if (baseAnswers.length > 1) baseAnswers[1] = savedCombinedAnswers[1]; }
        }

        for (int i = 2; i < _questions.length; i++) {
          if (i < baseAnswers.length && i < savedCombinedAnswers.length && savedCombinedAnswers[i] != null) {
            final questionConfig = _questions[i];
            final dynamic rawAnswer = savedCombinedAnswers[i];

            if (questionConfig['type'] == 'text_long') { // Manejo de la nueva pregunta
              baseAnswers[i] = rawAnswer;
              _descripcionEmpresaController.text = rawAnswer?.toString() ?? '';
            } else if (questionConfig['type'] == 'tiered_choice') {
              if (rawAnswer is String) {
                final parts = rawAnswer.split(': ');
                String? mainOpt = parts.isNotEmpty ? parts[0] : null;
                
                if (mainOpt != null && (questionConfig['main_options'] as List<String>).contains(mainOpt)) {
                  if (parts.length > 1) {
                    String subPart = parts[1];
                    if (parts.length > 2 && subPart == 'Otro') {
                      baseAnswers[i] = '$mainOpt: Otro';
                        if (i < _otrosControllers.length) {
                        _otrosControllers[i].text = parts.sublist(2).join(': ');
                      }
                    } else {
                      List<String> possibleSubOptions = (questionConfig['sub_options_map'][mainOpt] as List<String>? ?? []);
                      if (possibleSubOptions.contains(subPart)) {
                          baseAnswers[i] = rawAnswer;
                      } else if (subPart == 'Otro') {
                          baseAnswers[i] = '$mainOpt: Otro';
                      } else {
                          baseAnswers[i] = null;
                      }
                    }
                  } else { 
                      baseAnswers[i] = null; 
                  }
                } else { baseAnswers[i] = null; }
              } else { baseAnswers[i] = null; }
            } else if (questionConfig['type'] == 'choice') {
              if (rawAnswer is String) {
                if (rawAnswer.startsWith('Otro: ')) {
                  baseAnswers[i] = 'Otro';
                  if (i < _otrosControllers.length) {
                    _otrosControllers[i].text = rawAnswer.substring('Otro: '.length);
                  }
                } else { baseAnswers[i] = rawAnswer; }
              } else { baseAnswers[i] = rawAnswer; }
            } else { 
              baseAnswers[i] = rawAnswer;
            }
          } else if (i < baseAnswers.length) {
             baseAnswers[i] = null; // Si no hay respuesta guardada o índice fuera de rango
             if (i < _otrosControllers.length) _otrosControllers[i].clear();
             if (_questions[i]['type'] == 'text_long') _descripcionEmpresaController.clear();
          }
        }
        setState(() { _answers = baseAnswers; });
        
        if (projectData['resultado_ia_json'] != null) {
          resultadoIA = projectData['resultado_ia_json'] as String;
        }
        _prepareUIDataForCurrentPage();
      } else if (mounted) {
        if (_answers.isNotEmpty) _answers[0] = _nombreProyectoController.text;
        _prepareUIDataForCurrentPage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el proyecto desde SQLite.'))
        );
      }
    } catch (e) {
      print("Error cargando proyecto desde SQLite: $e");
      if (mounted) {
        if (_answers.isNotEmpty) _answers[0] = _nombreProyectoController.text;
        _prepareUIDataForCurrentPage();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el proyecto: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProject = false);
      }
    }
  }


  List<dynamic> _getCombinedAnswers() {
    List<dynamic> combined = List.filled(_questions.length, null);
    
    for(int i = 0; i < _answers.length && i < combined.length; i++) {
        combined[i] = _answers[i];
    }

    if (combined.isNotEmpty) combined[0] = _nombreProyectoController.text.trim();

    if (combined.length > 1 && combined[1] == 'Sí') {
      combined[1] = 'Sí: ${_nombreEmpresaController.text.trim()}';
    }
    
    // Para la nueva pregunta de descripción ('text_long'), si _answers está actualizado
    // (lo cual sucede en el onChanged del TextField respectivo), ya estará correctamente en 'combined'.
    // No se necesita lógica adicional específica aquí para ese tipo de pregunta.

    for (int i = 0; i < _questions.length; i++) {
      if (i >= combined.length || combined[i] == null) continue;

      final questionConfig = _questions[i];
      if (questionConfig['type'] == 'tiered_choice') {
        String answer = combined[i] as String;
        if (answer.endsWith(': Otro')) { 
             if (i < _otrosControllers.length && _otrosControllers[i].text.trim().isNotEmpty) {
                combined[i] = '$answer: ${_otrosControllers[i].text.trim()}';
             }
        }
      } else if (questionConfig['type'] == 'choice') {
        if (combined[i] == 'Otro') {
          if (i < _otrosControllers.length && (questionConfig['options'] as List<String>).contains('Otro')) {
             combined[i] = 'Otro: ${_otrosControllers[i].text.trim()}';
          }
        }
      }
    }
    return combined;
  }

  Future<void> _saveOrUpdateProjectAnswers({String? nuevoResultadoIA, bool isFinalSave = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    List<dynamic> answersToSave = _getCombinedAnswers();
    String nombreProyectoParaDb = _nombreProyectoController.text.trim();
    String? resultadoAGuardar = nuevoResultadoIA ?? (resultadoIA.isNotEmpty ? resultadoIA : null) ;

    if (nombreProyectoParaDb.isEmpty && (_currentPage == 0 || isFinalSave)) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('El nombre del proyecto no puede estar vacío para guardar.'))
            );
        }
        setState(() => _isSaving = false);
        return;
    }
    if (nombreProyectoParaDb.isEmpty && _currentSqliteProjectId == null) {
        nombreProyectoParaDb = "Proyecto sin título ${DateTime.now().millisecondsSinceEpoch}";
        _nombreProyectoController.text = nombreProyectoParaDb;
        if (answersToSave.isNotEmpty) answersToSave[0] = nombreProyectoParaDb; 
    }
    
    final User? firebaseUser = _auth.currentUser;
    String? firebaseAuthUid = firebaseUser?.uid;

    Map<String, dynamic> firestoreData = {
      'usuario_id_sqlite': widget.usuarioId,
      'firebaseAuthUid': firebaseAuthUid,
      'nombre_proyecto': nombreProyectoParaDb,
      'respuestas_json': jsonEncode(answersToSave),
      'resultado_ia_json': resultadoAGuardar,
      'fecha_modificacion': FieldValue.serverTimestamp(),
      'sqlite_project_id': _currentSqliteProjectId,
    };

    if (_currentFirestoreProjectId == null) {
      firestoreData['fecha_creacion'] = FieldValue.serverTimestamp();
    }
    firestoreData.removeWhere((key, value) => value == null && key != 'resultado_ia_json' && key != 'firebaseAuthUid');

    try {
      int? tempSqliteId = _currentSqliteProjectId;
      String? tempFirestoreIdParaSqlite;

      if (tempSqliteId == null) {
        final newSqliteId = await DBHelper.insertarProyecto(
          usuarioId: widget.usuarioId,
          nombreProyecto: nombreProyectoParaDb,
          respuestas: answersToSave,
          resultadoIA: resultadoAGuardar,
        );
        if (newSqliteId != -1) {
          tempSqliteId = newSqliteId;
          _currentSqliteProjectId = newSqliteId;
          firestoreData['sqlite_project_id'] = newSqliteId;
          print("Proyecto nuevo guardado en SQLite con ID: $newSqliteId");
        } else {
          throw Exception("Error al guardar nuevo proyecto en SQLite.");
        }
      } else {
        await DBHelper.actualizarProyecto(
          proyectoId: tempSqliteId,
          nombreProyecto: nombreProyectoParaDb.isNotEmpty ? nombreProyectoParaDb : null,
          respuestas: answersToSave,
          resultadoIA: resultadoAGuardar,
          firestoreProjectId: _currentFirestoreProjectId,
        );
        print("Proyecto SQLite ID: $tempSqliteId actualizado.");
      }

      if (firebaseAuthUid != null) {
        if (_currentFirestoreProjectId == null) {
          if (tempSqliteId == null) throw Exception("ID de SQLite no disponible para nuevo proyecto en Firestore.");
          
          DocumentReference docRef = await _firestore.collection('proyectos').add(firestoreData);
          _currentFirestoreProjectId = docRef.id;
          tempFirestoreIdParaSqlite = _currentFirestoreProjectId;
          print("Proyecto nuevo guardado en Firestore con ID: $_currentFirestoreProjectId (SQLite ID: $tempSqliteId, Firebase UID: $firebaseAuthUid)");
        } else {
          if (nombreProyectoParaDb.isEmpty && firestoreData.containsKey('nombre_proyecto')) {
              firestoreData.remove('nombre_proyecto');
          }
          await _firestore.collection('proyectos').doc(_currentFirestoreProjectId).update(firestoreData);
          print("Proyecto Firestore ID: $_currentFirestoreProjectId actualizado.");
        }

        if (tempFirestoreIdParaSqlite != null && tempSqliteId != null) {
          await DBHelper.actualizarProyecto(
              proyectoId: tempSqliteId,
              firestoreProjectId: tempFirestoreIdParaSqlite
          );
          print("ID de Firestore $tempFirestoreIdParaSqlite guardado en SQLite para proyecto ID: $tempSqliteId");
        }
      } else {
        print("Wizard: No hay usuario de Firebase Auth, no se guardará/actualizará en Firestore.");
        if (isFinalSave && mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Proyecto guardado localmente. Inicia sesión para sincronizar con la nube.'))
            );
        }
      }

    } catch (e) {
      print("Excepción al guardar/actualizar proyecto: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar el guardado del proyecto: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleSaveAndClose() async {
    if (_isSaving) return; 
    
    String currentProjectName = _nombreProyectoController.text.trim();
    if (currentProjectName.isEmpty && _currentSqliteProjectId == null) {
        if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Por favor, ingresa un nombre para el proyecto antes de guardar y cerrar.'))
            );
        }
        return;
    }
    await _saveOrUpdateProjectAnswers(isFinalSave: true); 

    if (mounted && !_isSaving) { 
      Navigator.of(context).pop(); 
    }
  }

  @override
  void dispose() {
    _nombreProyectoController.dispose();
    _nombreEmpresaController.dispose();
    _descripcionEmpresaController.dispose(); // Disponer el controller de descripción
    for (final c in _otrosControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String construirPrompt(List<dynamic> currentAnswers) {
    return '''
Actúa como un experto en branding y redacción estratégica para pequeñas y medianas empresas. Con base en las respuestas proporcionadas, genera únicamente la identidad de marca, clara, coherente y aplicable de inmediato, adecuada para una PYME en crecimiento o recién formada.
Si el usuario ha proporcionado un nombre de su empresa, no pongas "(ya proporcionado)" al final del nombre del proyecto, simplemente usa el nombre proporcionado.
Nombre del Proyecto: ${currentAnswers.isNotEmpty ? currentAnswers[0] : ''}

Presenta la información en secciones con subtítulos claros (sin negritas, asteriscos ni frases de cortesía). Cada sección debe ser específica, profesional y realista, con ejemplos y recomendaciones adaptadas al contexto de una PYME. No incluyas conclusiones ni diseño de logotipo.

Incluye los siguientes apartados, en este orden:

Propósito de la empresa
Problema que resuelve
Perfil del cliente ideal
Propuesta de valor
Nombre de la marca (si es posible sugerir uno) Consideracion adicional: Si el usuario puso un nombre solo ponlo, no pongas entre parentesis "ya proporcionado)"
Eslogan (si es posible sugerir uno)
Estilo visual sugerido para la marca
Paleta de colores recomendada
Tipografía sugerida
Imágenes, ilustraciones o elementos gráficos recomendados
Elementos gráficos complementarios (iconos, patrones, etc.)
Diseño web y presencia digital recomendada
Valores fundamentales
Tono y voz de comunicación
Guía breve de estilo de marca
Misión, visión y valores
Personalidad de la marca
Empaque (si aplica)
Experiencia del cliente
Análisis competitivo básico
Aspectos visuales y comunicativos recomendados
Visión a futuro
Impacto deseado en la industria o comunidad

Respuestas del usuario:

1. ¿Tu empresa tiene nombre?
${currentAnswers.length > 1 ? currentAnswers[1] : ''}

2. ¿Cuál es el giro de tu negocio?
${currentAnswers.length > 2 ? currentAnswers[2] : ''}

3. Describa brevemente a qué se dedica su empresa.
${currentAnswers.length > 3 ? currentAnswers[3] : ''}

4. ¿De qué tamaño consideras que es tu empresa?
${currentAnswers.length > 4 ? currentAnswers[4] : ''}

5. ¿Por qué existe tu empresa?
${currentAnswers.length > 5 ? currentAnswers[5] : ''}

6. ¿Qué te motivó a crearla?
${currentAnswers.length > 6 ? currentAnswers[6] : ''}

7. ¿Qué problema resuelve tu empresa en el mercado?
${currentAnswers.length > 7 ? currentAnswers[7] : ''}

8. ¿Quiénes son tus clientes ideales?
${currentAnswers.length > 8 ? currentAnswers[8] : ''}

9. ¿Dónde se ubican tus clientes ideales?
${currentAnswers.length > 9 ? currentAnswers[9] : ''}

10. ¿Cuáles son los intereses de tus clientes ideales?
${currentAnswers.length > 10 ? currentAnswers[10] : ''}

11. ¿Qué necesidades tienen tus clientes ideales?
${currentAnswers.length > 11 ? currentAnswers[11] : ''}

12. ¿Cómo quieres que tu marca se perciba visualmente?
${currentAnswers.length > 12 ? currentAnswers[12] : ''}

13. ¿Qué valores fundamentales guían las decisiones y acciones de tu empresa?
${currentAnswers.length > 13 ? currentAnswers[13] : ''}

14. Si tu marca fuera una persona, ¿cómo hablaría?
${currentAnswers.length > 14 ? currentAnswers[14] : ''}

15. ¿Qué tipo de paleta de colores te gustaría que tuviera tu empresa?
${currentAnswers.length > 15 ? currentAnswers[15] : ''}

16. ¿Qué tipo de tipografías te gustaría que tuviera tu empresa?
${currentAnswers.length > 16 ? currentAnswers[16] : ''}

17. ¿Qué estilo de diseño prefieres?
${currentAnswers.length > 17 ? currentAnswers[17] : ''}

18. De esas marcas que admiras, ¿qué te gusta de su forma de comunicar y conectar con la gente?
${currentAnswers.length > 18 ? currentAnswers[18] : ''}

19. ¿Cómo imaginas tu empresa a futuro?
${currentAnswers.length > 19 ? currentAnswers[19] : ''}

20. ¿Qué impacto quieres que tenga tu empresa en la industria?
${currentAnswers.length > 20 ? currentAnswers[20] : ''}

Redacta cada sección de forma clara y estructurada, usando lenguaje profesional y realista, con ejemplos y recomendaciones específicas para el contexto de una PYME. No incluyas frases de cortesía, conclusiones, ni agregues el diseño del logotipo y no pongas negritas porque en el resultado se ve con "*".
''';
  }

  Future<void> _generarPdf(BuildContext context) async {
    final pdf = pw.Document();
    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
        fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/ARIAL.TTF'));
        fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/ARIALBD.TTF'));
    } catch (e) {
        print("Error loading fonts: $e");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al cargar fuentes para PDF. Usando fuentes estándar.'))
            );
        }
    }

    final fecha = DateFormat('dd/MM/yy').format(DateTime.now());
    final String nombreProyectoParaPdf = _nombreProyectoController.text.trim().isNotEmpty
                                        ? _nombreProyectoController.text.trim()
                                        : "Proyecto Sin Nombre";

    final logoBytes = await rootBundle.load('assets/runilog.png'); 
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final sectionTitles = [
      'Propósito de la empresa', 'Problema que resuelve', 'Perfil del cliente ideal',
      'Propuesta de valor', 'Nombre de la marca', 'Eslogan',
      'Estilo visual sugerido para la marca', 'Paleta de colores recomendada', 'Tipografía sugerida',
      'Imágenes, ilustraciones o elementos gráficos recomendados', 'Elementos gráficos complementarios',
      'Diseño web y presencia digital recomendada', 'Valores fundamentales',
      'Tono y voz de comunicación', 'Guía breve de estilo de marca', 'Misión, visión y valores',
      'Personalidad de la marca', 'Empaque', 'Experiencia del cliente',
      'Análisis competitivo básico', 'Aspectos visuales y comunicativos recomendados',
      'Visión a futuro', 'Impacto deseado en la industria o comunidad',
    ];

    final lines = resultadoIA.split('\n');
    List<pw.Widget> widgets = [];

    final defaultTextStyle = pw.TextStyle(font: fontRegular, fontSize: 12, fontWeight: pw.FontWeight.normal, lineSpacing: 1.5);
    final boldTextStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.black, fontWeight: pw.FontWeight.bold, lineSpacing: 1.5);

    for (final line in lines) {
      final trimmed = line.trim();
      bool isTitle = sectionTitles.any((title) =>
              trimmed.toLowerCase().startsWith(title.toLowerCase()) &&
              trimmed.isNotEmpty);

      if (isTitle) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
            child: pw.Text(
              trimmed,
              style: fontBold != null ? boldTextStyle : defaultTextStyle.copyWith(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ),
        );
      } else if (trimmed.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              trimmed,
              style: fontRegular != null ? defaultTextStyle : pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal, lineSpacing: 1.5),
              textAlign: pw.TextAlign.justify,
            ),
          )
        );
      }
    }

    final double logoWatermarkWidth = 180;
    final double textWatermarkVisualWidth = 400;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 50, 40, 60),
      buildBackground: (context) => pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Positioned(
            left: (PdfPageFormat.a4.width - (2 * 40) - textWatermarkVisualWidth) / 2,
            top: 280,
            child: pw.Transform.rotate(
              angle: -0.785,
              child: pw.Opacity(
                opacity: 0.07,
                child: pw.Text(
                  "ru'ni - Identidad de Marca",
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 40, color: PdfColors.grey300),
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: (PdfPageFormat.a4.width - (2 * 40) - logoWatermarkWidth) / 2,
            top: 360,
            child: pw.Opacity(
              opacity: 0.10,
              child: pw.Image(
                logoImage,
                width: logoWatermarkWidth,
              ),
            ),
          ),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(bottom: 15, top:0),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1))
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Image(logoImage, width: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    nombreProyectoParaPdf,
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Generado por ru'ni el $fecha",
                    style: pw.TextStyle(
                        font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                  ),
                ]
              )
            ],
          ),
        ),
        build: (context) => widgets,
         footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${nombreProyectoParaPdf.replaceAll(' ', '_')}_Identidad_Marca.pdf'
    );
  }

  bool _isCurrentAnswerValid() {
    final currentQuestion = _questions[_currentPage];
    final answer = _answers.length > _currentPage ? _answers[_currentPage] : null; 

    if (_currentPage == 0) {
      return _nombreProyectoController.text.trim().isNotEmpty;
    }

    if (_currentPage == 1) { 
      final companyHasNameAnswer = _answers.length > 1 ? _answers[1] : null;
      if (companyHasNameAnswer == 'Sí') {
        return _nombreEmpresaController.text.trim().isNotEmpty;
      }
      return companyHasNameAnswer != null;
    }
    
    // Validación para la nueva pregunta de descripción de empresa
    if (_currentPage < _questions.length && currentQuestion['type'] == 'text_long') {
        return _descripcionEmpresaController.text.trim().isNotEmpty;
    }

    if (currentQuestion['type'] == 'tiered_choice') {
      if (_selectedMainAudienceOption == null || _selectedSubAudienceOption == null) {
        return false;
      }
      if (_selectedSubAudienceOption == 'Otro') {
        return _currentPage < _otrosControllers.length && _otrosControllers[_currentPage].text.trim().isNotEmpty;
      }
      return answer != null;
    }

    if (currentQuestion['type'] == 'choice') {
      if (answer == null) return false;
      if (answer == 'Otro') {
         return _currentPage < _otrosControllers.length && _otrosControllers[_currentPage].text.trim().isNotEmpty;
      }
      return true; 
    }
    return answer != null;
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoadingProject) {
      return Scaffold(
        appBar: AppBar(title: Text('Cargando Proyecto...'), backgroundColor: Color(0xFFF4A261)),
        backgroundColor: Color(0xFF1E1E2C),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))),
      );
    }

    if (_answers.length != _questions.length) {
        _answers = List.filled(_questions.length, null, growable: true);
        if (_currentSqliteProjectId == null && _answers.isNotEmpty) {
             _answers[0] = _nombreProyectoController.text;
        }
    }
    if (_otrosControllers.length != _questions.length) {
        _otrosControllers = List.generate(_questions.length, (index) => TextEditingController());
    }

    final currentQuestion = _questions[_currentPage];
    double progress = (_currentPage + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSqliteProjectId == null
            ? 'Nuevo Proyecto de Marca'
            : 'Editando: ${_nombreProyectoController.text.isNotEmpty ? _nombreProyectoController.text : "Proyecto sin título"}'),
        backgroundColor: Color(0xFFF4A261),
        leading: IconButton(
          icon: Icon(_currentPage == 0 ? Icons.close : Icons.arrow_back),
          onPressed: () async {
            if (_currentPage == 0) {
              Navigator.pop(context);
            } else {
              await _saveOrUpdateProjectAnswers(); 
              setState(() {
                _currentPage--;
                _prepareUIDataForCurrentPage();
              });
            }
          }
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _handleSaveAndClose,
            icon: Icon(Icons.save_alt, color: _isSaving ? Colors.grey : Colors.black87),
            label: Text(
              "Guardar y Cerrar",
              style: TextStyle(color: _isSaving ? Colors.grey : Colors.black87, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          SizedBox(width: 8), 
        ],
      ),
      backgroundColor: Color(0xFF1E1E2C),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16,8,16,16),
        child: Column(
          children: [
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Color(0xFF2C2C3A),
              color: Color(0xFFF4A261),
              borderRadius: BorderRadius.circular(5),
            ),
            SizedBox(height: 12),
            Text(
              'Paso ${_currentPage + 1} de ${_questions.length}',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(minHeight: 60),
              padding: EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text(
                currentQuestion['question'],
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_currentPage == 0) 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _nombreProyectoController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color(0xFF2C2C3A),
                            labelText: 'Nombre del Proyecto',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white38),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFFF4A261), width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (_answers.isNotEmpty) _answers[0] = value;
                            });
                          },
                        ),
                      )
                    else if (_currentPage == 1) 
                      Column(
                        children: [
                          ...(_questions[1]['options'] as List<String>).map<Widget>((option) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: RadioListTile<String>(
                                title: Text(option, style: TextStyle(color: Colors.white)),
                                value: option,
                                groupValue: _answers.length > 1 ? _answers[1] : null, 
                                onChanged: (value) {
                                  setState(() {
                                    if (_answers.length > 1) _answers[1] = value;
                                    if (value != 'Sí') {
                                      _nombreEmpresaController.clear();
                                    }
                                  });
                                },
                                activeColor: Color(0xFFF4A261),
                                selectedTileColor: Color(0xFF3A3A4A),
                                tileColor: Color(0xFF2C2C3A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                            );
                          }).toList(),
                          if (_answers.length > 1 && _answers[1] == 'Sí')
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0, left: 16, right: 16, bottom: 10),
                              child: TextField(
                                controller: _nombreEmpresaController,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Color(0xFF2C2C3A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  hintText: 'Escribe el nombre de tu empresa',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white38),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Color(0xFFF4A261), width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                   setState(() {}); 
                                },
                              ),
                            ),
                        ],
                      )
                    else if (currentQuestion['type'] == 'text_long')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _descripcionEmpresaController,
                          style: TextStyle(color: Colors.white),
                          maxLines: 3, // Para una descripción breve
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color(0xFF2C2C3A),
                            hintText: 'Ej: Ofrecemos soluciones de software personalizadas...',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white38),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFFF4A261), width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              // El índice de la nueva pregunta es 3
                              if (_answers.length > 3) _answers[3] = value;
                            });
                          },
                        ),
                      )
                    else if (currentQuestion['type'] == 'tiered_choice')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            child: Text(
                              currentQuestion['main_question_text'],
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                          ...(currentQuestion['main_options'] as List<String>).map<Widget>((mainOption) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: RadioListTile<String>(
                                title: Text(mainOption, style: TextStyle(color: Colors.white)),
                                value: mainOption,
                                groupValue: _selectedMainAudienceOption,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMainAudienceOption = value;
                                    _selectedSubAudienceOption = null;
                                    if (_currentPage < _answers.length) _answers[_currentPage] = null;
                                    if (_currentPage < _otrosControllers.length) {
                                      _otrosControllers[_currentPage].clear();
                                    }
                                  });
                                },
                                activeColor: Color(0xFFF4A261),
                                tileColor: Color(0xFF2C2C3A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          }).toList(),

                          if (_selectedMainAudienceOption != null &&
                              (currentQuestion['sub_options_map'] as Map).containsKey(_selectedMainAudienceOption))
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                    child: Text(
                                      'Más específicamente, ¿para qué tipo de ${_selectedMainAudienceOption?.toLowerCase()}?',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  ...((currentQuestion['sub_options_map'][_selectedMainAudienceOption!]) as List<String>)
                                      .map<Widget>((subOption) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: RadioListTile<String>(
                                        title: Text(subOption, style: TextStyle(color: Colors.white)),
                                        value: subOption,
                                        groupValue: _selectedSubAudienceOption,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedSubAudienceOption = value;
                                            if (_currentPage < _answers.length) {
                                              if (value != 'Otro') {
                                                _answers[_currentPage] = '$_selectedMainAudienceOption: $value';
                                                if (_currentPage < _otrosControllers.length) {
                                                  _otrosControllers[_currentPage].clear();
                                                }
                                              } else {
                                                _answers[_currentPage] = '$_selectedMainAudienceOption: Otro';
                                              }
                                            }
                                          });
                                        },
                                        activeColor: Color(0xFFF4A261),
                                        tileColor: Color(0xFF2C2C3A),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    );
                                  }).toList(),
                                  if (_selectedSubAudienceOption == 'Otro')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0, left: 16, right: 16, bottom: 10),
                                      child: TextField(
                                        controller: (_currentPage < _otrosControllers.length) ? _otrosControllers[_currentPage] : TextEditingController(), 
                                        style: TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Color(0xFF2C2C3A),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                          hintText: 'Especifica tu respuesta para "Otro"',
                                          hintStyle: TextStyle(color: Colors.white54),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.white38),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Color(0xFFF4A261), width: 2),
                                          ),
                                        ),
                                        onChanged: (text) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      )
                    else if (currentQuestion['type'] == 'choice')
                      Column(
                        children: [
                          ...(currentQuestion['options'] as List<String>).map<Widget>((option) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: RadioListTile<String>(
                                title: Text(option, style: TextStyle(color: Colors.white)),
                                value: option,
                                groupValue: (_currentPage < _answers.length) ? _answers[_currentPage] : null, 
                                onChanged: (value) {
                                  setState(() {
                                    if (_currentPage < _answers.length) _answers[_currentPage] = value;
                                    if (value != 'Otro') {
                                      if(_currentPage < _otrosControllers.length) {
                                        _otrosControllers[_currentPage].clear();
                                      }
                                    }
                                  });
                                },
                                activeColor: Color(0xFFF4A261),
                                selectedTileColor: Color(0xFF3A3A4A),
                                tileColor: Color(0xFF2C2C3A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                            );
                          }).toList(),
                          if ((_currentPage < _answers.length && _answers[_currentPage] == 'Otro'))
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0, left: 16, right: 16, bottom: 10),
                              child: TextField(
                                controller: (_currentPage < _otrosControllers.length) ? _otrosControllers[_currentPage] : TextEditingController(), 
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Color(0xFF2C2C3A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  hintText: 'Especifica tu respuesta',
                                  hintStyle: TextStyle(color: Colors.white54),
                                   enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white38),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Color(0xFFF4A261), width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {}); 
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top:16.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded( 
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        if (_currentPage == 0) {
                          Navigator.pop(context);
                        } else {
                          await _saveOrUpdateProjectAnswers();
                          setState(() {
                             _currentPage--;
                             _prepareUIDataForCurrentPage();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6C757D), 
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric( vertical: 14),
                          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ).copyWith(
                        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        )
                      ),
                      child: Text(_currentPage == 0 ? "Cancelar" : "Atrás"),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded( 
                    child: ElevatedButton(
                      onPressed: _isSaving || !_isCurrentAnswerValid()
                          ? null
                          : () async {
                              await _saveOrUpdateProjectAnswers(isFinalSave: _currentPage == _questions.length - 1);

                              if (_currentPage < _questions.length - 1) {
                                setState(() {
                                  _currentPage++;
                                  _prepareUIDataForCurrentPage();
                                });
                              } else { 
                                final combinedAnswersForPrompt = _getCombinedAnswers();
                                final prompt = construirPrompt(combinedAnswersForPrompt);

                                 if(mounted) {
                                   Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Scaffold(
                                        backgroundColor: Color(0xFF1E1E2C),
                                        appBar: AppBar(title: Text("Generando para: ${combinedAnswersForPrompt.isNotEmpty ? combinedAnswersForPrompt[0] : 'Proyecto'}"), backgroundColor: Color(0xFFF4A261), automaticallyImplyLeading: false,),
                                        body: Center(child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(color: Color(0xFFF4A261), strokeWidth: 5,),
                                            SizedBox(height: 20),
                                            Text("Un momento, procesando solicitud...", style: TextStyle(color: Colors.white70, fontSize: 16))
                                          ],
                                        ))
                                      )
                                    ),
                                  );
                                 }

                                try {
                                  final respuestaDeGemini = await _geminiService.chatWithGemini(prompt);
                                  setState(() {
                                    resultadoIA = respuestaDeGemini;
                                  });
                                  await _saveOrUpdateProjectAnswers(nuevoResultadoIA: respuestaDeGemini, isFinalSave: true);

                                  if (mounted) {
                                    Navigator.pop(context); 
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResultadoScreen(
                                          resultado: respuestaDeGemini,
                                          onExportarPdf: _generarPdf,
                                          onVolverAlInicio: () {
                                            Navigator.of(context).popUntil((route) => route.isFirst);
                                          }
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  String errorMsg = "Error al generar la identidad para '${combinedAnswersForPrompt.isNotEmpty ? combinedAnswersForPrompt[0] : 'este proyecto'}'.\nPor favor, intenta de nuevo más tarde o revisa tu conexión y la configuración de la API.\n\nDetalle técnico: ${e.toString()}";
                                  setState(() {
                                    resultadoIA = errorMsg;
                                  });
                                  await _saveOrUpdateProjectAnswers(nuevoResultadoIA: errorMsg, isFinalSave: true);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al generar identidad: ${e.toString()}', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, duration: Duration(seconds: 5),)
                                    );
                                     Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResultadoScreen(
                                          resultado: resultadoIA,
                                          onExportarPdf: (ctx) async {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(content: Text('No se puede exportar PDF debido a un error previo en la generación.'))
                                            );
                                          },
                                          onVolverAlInicio: () {
                                            Navigator.of(context).popUntil((route) => route.isFirst);
                                          }
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _isCurrentAnswerValid() ? Color(0xFFF4A261) : Color(0xFF4A4A58),
                          foregroundColor: _isCurrentAnswerValid() ? Colors.black87 : Colors.white38, 
                          padding: EdgeInsets.symmetric(vertical: 14),
                          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ).copyWith(
                        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        )
                      ),
                      child: _isSaving
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _isCurrentAnswerValid() ? Colors.black87 : Colors.white38,))
                        : Text(
                        _currentPage == _questions.length - 1 ? "Finalizar y Generar" : "Siguiente",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}