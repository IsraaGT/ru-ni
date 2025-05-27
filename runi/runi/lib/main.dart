import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runi/BienvenidaActivity.dart';
import 'package:runi/db.dart';
import 'package:runi/herramientas.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Asegúrate que esta sea la ruta correcta a tu firebase_options.dart
// import 'firebase_options.dart'; // Descomenta si es necesario para Firebase.initializeApp()

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ru´ni',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF283B63), // Azul oscuro para el tema base
          brightness: Brightness.dark, // Establecer el tema general como oscuro
          primary: const Color(0xFFF4A261), // Naranja como acento principal
          secondary: const Color(0xFFE76F51), // Otro tono naranja/rojo
          surface: const Color(0xFF2C2C3A), // Color para cards, diálogos
          background: const Color(0xFF1E1E2C), // Fondo principal de la app
          onPrimary: Colors.black, // Texto sobre el color primario (naranja)
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
          error: Colors.redAccent, // Color para errores
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C2C3A),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme( // Estilo para TextFields
          filled: true,
          fillColor: Colors.white, // Fondo blanco para los campos de texto
          labelStyle: TextStyle(color: Colors.grey.shade700),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: const Color(0xFFF4A261), width: 2), // Color primario al enfocar
          ),
          errorStyle: TextStyle(color: Colors.redAccent[100]), // Color más claro para error sobre fondo oscuro
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white, // Texto blanco para TextButtons sobre fondo oscuro
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LogoScreen(),
        '/bienvenida': (context) => const BienvenidaScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  bool _showAuthForms = false;
  bool _showRuniLogo = true; // El logo de Runi empieza visible

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Pequeña pausa inicial para mostrar el logo
    await Future.delayed(const Duration(seconds: 2));

    // Verificar sesión
    final usuarioActivo = await DBHelper.obtenerUsuarioActivo();
    if (mounted) {
      if (usuarioActivo != null) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // Si no hay sesión, animar la desaparición del logo y aparición de los forms
        setState(() {
          _showRuniLogo = false; // Iniciar animación de desaparición del logo
        });
        // Esperar a que la animación del logo termine (o un poco más)
        await Future.delayed(const Duration(milliseconds: 1500)); // Duración de la animación de opacidad
        if (mounted) {
          setState(() {
            _showAuthForms = true; // Mostrar formularios de autenticación
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF283B63), // Fondo azul oscuro
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Logo de Runi que desaparece
            AnimatedOpacity(
              opacity: _showRuniLogo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1500), // Duración de la animación
              child: Image.asset(
                'assets/runilog.png',
                height: 200,
              ),
            ),
            // Formularios de autenticación que aparecen después
            // Usar AnimatedOpacity también para la aparición de los formularios
            AnimatedOpacity(
              opacity: _showAuthForms ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500), // Una aparición más rápida
              child: _showAuthForms ? const AuthSwitcher() : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}


class AuthSwitcher extends StatefulWidget {
  const AuthSwitcher({super.key});

  @override
  State<AuthSwitcher> createState() => _AuthSwitcherState();
}

class _AuthSwitcherState extends State<AuthSwitcher> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation = Tween<Offset>(
          begin: Offset(isLogin ? 1.0 : -1.0, 0.0), // Slide desde la derecha para login, izq para registro
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCirc)); // Curva más suave
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: isLogin
          ? LoginForm(key: const ValueKey('loginForm'), onSwitch: () => setState(() => isLogin = false))
          : RegisterForm(key: const ValueKey('registerForm'), onSwitch: () => setState(() => isLogin = true)),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback onSwitch;
  const LoginForm({super.key, required this.onSwitch});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final auth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscureTextPassword = true;
  String error = '';
  bool _isLoggingIn = false;
  bool _isGoogleSigningIn = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    // ... (Lógica de login con email sin cambios significativos, solo la llamada a _translateFirebaseAuthErrorMessage)
    if (_isLoggingIn || _isGoogleSigningIn) return;
    setState(() { _isLoggingIn = true; error = ''; });
    try {
      await auth.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      await DBHelper.insertarUsuario(emailController.text.trim(), passwordController.text.trim(), status: 1);
      if (mounted) Navigator.pushReplacementNamed(context, '/bienvenida');
    } on FirebaseAuthException catch (e) {
       if (mounted) setState(() => error = _translateFirebaseAuthErrorMessage(e.code, isLogin: true));
    } catch (e) {
      if (mounted) setState(() => error = "Ocurrió un error inesperado.");
      print("Error en login: $e");
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoggingIn || _isGoogleSigningIn) return;
    print("BOTÓN GOOGLE PRESIONADO - Llamando a _signInWithGoogle...");
    setState(() { _isGoogleSigningIn = true; error = ''; });

    GoogleSignInAccount? googleUser;
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      print("GOOGLE_SIGN_IN: Calling googleSignIn.signIn()...");
      googleUser = await googleSignIn.signIn();
      print("GOOGLE_SIGN_IN: googleSignIn.signIn() call completed. googleUser is: ${googleUser?.email ?? 'null'}");

      if (googleUser == null) {
        print("GOOGLE_SIGN_IN: googleUser is null. User likely canceled.");
        if (mounted) {
            setState(() {
                // No mostrar error si el usuario simplemente canceló el diálogo
                // error = "Inicio de sesión con Google cancelado.";
                _isGoogleSigningIn = false;
            });
        }
        return;
      }

      print("GOOGLE_SIGN_IN: Obtaining googleAuth...");
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print("GOOGLE_SIGN_IN: googleAuth obtained. idToken is ${googleAuth.idToken != null ? 'present' : 'absent'}, accessToken is ${googleAuth.accessToken != null ? 'present' : 'absent'}.");

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print("GOOGLE_SIGN_IN: Firebase AuthCredential created.");

      print("GOOGLE_SIGN_IN: Calling FirebaseAuth.instance.signInWithCredential()...");
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;
      print("GOOGLE_SIGN_IN: signInWithCredential() completed. firebaseUser is: ${firebaseUser?.email ?? 'null'}");

      if (firebaseUser != null) {
        print("GOOGLE_SIGN_IN: Firebase sign-in successful. User: ${firebaseUser.email}");
        await DBHelper.insertarUsuario(firebaseUser.email!, "[GOOGLE_USER]", status: 1);
        print("GOOGLE_SIGN_IN: User inserted/updated in DBHelper.");
        if (mounted) Navigator.pushReplacementNamed(context, '/bienvenida');
      } else {
        print("GOOGLE_SIGN_IN: firebaseUser is null after signInWithCredential.");
        if(mounted) setState(() => error = "No se pudo obtener el usuario de Firebase después del login con Google.");
      }
    } on PlatformException catch (e) { // Captura errores específicos del plugin google_sign_in
        print("GOOGLE_SIGN_IN: PlatformException during Google Sign In: code=${e.code}, message=${e.message}, details=${e.details}");
        if (mounted) {
          String displayError = "Error con Google Sign-In.";
          if (e.code == 'sign_in_canceled') {
             // displayError = "Inicio de sesión con Google cancelado."; // No mostrar error si cancela
             return; // Simplemente no hacer nada si cancela
          } else if (e.code == 'network_error') {
             displayError = "Error de red con Google. Verifica tu conexión.";
          } else if (e.code == 'sign_in_failed' || e.message?.contains('ApiException: 10') == true) {
             displayError = "Falló el inicio de sesión con Google. Revisa la configuración SHA-1 de tu app y el archivo google-services.json.";
          } else {
             displayError = e.message ?? "Error desconocido de plataforma con Google.";
          }
          setState(() { error = displayError;});
        }
    } on FirebaseAuthException catch (e) {
      print("GOOGLE_SIGN_IN: FirebaseAuthException: code=${e.code}, message=${e.message}");
      if (mounted) setState(() => error = _translateFirebaseAuthErrorMessage(e.code, isLogin: true));
    } catch (e, s) {
      print("GOOGLE_SIGN_IN: Generic Exception: $e");
      print("GOOGLE_SIGN_IN: Stack Trace: $s");
      if (mounted) setState(() => error = "Error inesperado con Google Sign-In.");
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
      print("GOOGLE_SIGN_IN: _signInWithGoogle() finished.");
    }
  }

  String _translateFirebaseAuthErrorMessage(String errorCode, {bool isLogin = false}) {
    // ... (Tu función de traducción, ajustada para tener mensajes más específicos)
    if (isLogin) {
        switch (errorCode) {
            case 'user-not-found': return 'No se encontró usuario con este correo.';
            case 'wrong-password': return 'Contraseña incorrecta.';
            // ... otros errores de login ...
        }
    } else { // Errores de registro
        switch (errorCode) {
            case 'email-already-in-use': return 'Este correo ya está registrado.';
            // ... otros errores de registro ...
        }
    }
    // Errores comunes
    switch (errorCode) {
        case 'invalid-email': return 'El formato del correo no es válido.';
        case 'user-disabled': return 'Este usuario ha sido deshabilitado.';
        case 'too-many-requests': return 'Demasiados intentos. Intenta más tarde.';
        case 'network-request-failed': return 'Error de red. Verifica tu conexión.';
        case 'account-exists-with-different-credential': return 'Ya existe una cuenta con este correo pero con un método de inicio de sesión diferente.';
        case 'popup-closed-by-user': return 'Proceso de inicio de sesión cancelado.';
        case 'unavailable': return 'Google Play Services no disponible o necesita actualizarse.';
        default: return 'Ocurrió un error de autenticación ($errorCode).';
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isLoading = _isLoggingIn || _isGoogleSigningIn;
    return AuthFormContainer(
      children: [
        Image.asset('assets/runilog.png', height: 100),
        const SizedBox(height: 20),
        Text("Iniciar Sesión", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        AuthTextField(
          controller: emailController,
          label: 'Correo electrónico',
          keyboardType: TextInputType.emailAddress,
        ),
        AuthTextField(
          controller: passwordController,
          label: 'Contraseña',
          obscureText: obscureTextPassword,
          onToggleObscure: () => setState(() => obscureTextPassword = !obscureTextPassword),
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14), textAlign: TextAlign.center,),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: isLoading ? null : _loginWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary, // Usa color del tema
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isLoggingIn
              ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.onPrimary))
              : const Text('Iniciar sesión'),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(child: Divider(color: Colors.white54)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text("O", style: TextStyle(color: Colors.white54)),
            ),
            Expanded(child: Divider(color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: isLoading ? null : _signInWithGoogle,
          icon: _isGoogleSigningIn
              ? SizedBox.shrink()
              : Image.asset('assets/images/google_logo.png', height: 22.0), // Ruta corregida
          label: _isGoogleSigningIn
              ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue /* O Theme.of(context).colorScheme.primary */))
              : Text('Iniciar sesión con Google'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black.withOpacity(0.7), // Texto un poco más oscuro
            elevation: 2, // Sombra sutil
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: isLoading ? null : widget.onSwitch,
          child: const Text("¿No tienes cuenta? Regístrate aquí",
              style: TextStyle(fontSize: 15)), // Color del TextButton heredado del tema
        ),
      ],
    );
  }
}

class RegisterForm extends StatefulWidget {
  final VoidCallback onSwitch;
  const RegisterForm({super.key, required this.onSwitch});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final auth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool obscureTextPassword = true;
  bool obscureTextConfirm = true;
  String error = '';
  bool _isRegistering = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // ... (Lógica de registro sin cambios significativos, solo la llamada a _translateFirebaseAuthErrorMessage)
    if (_isRegistering) return;
    if (passwordController.text.trim() != confirmController.text.trim()) {
      setState(() => error = 'Las contraseñas no coinciden'); return;
    }
    if (passwordController.text.trim().length < 6) {
      setState(() => error = 'La contraseña debe tener al menos 6 caracteres.'); return;
    }
    setState(() { _isRegistering = true; error = ''; });
    try {
      await auth.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      await DBHelper.insertarUsuario(emailController.text.trim(), passwordController.text.trim(), status: 1);
      if (mounted) Navigator.pushReplacementNamed(context, '/bienvenida');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = _translateFirebaseAuthErrorMessage(e.code, isLogin: false));
    } catch (e) {
       if (mounted) setState(() => error = "Ocurrió un error inesperado durante el registro.");
      print("Error en registro: $e");
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

   String _translateFirebaseAuthErrorMessage(String errorCode, {bool isLogin = false}) {
    // ... (Tu función de traducción, ajustada para tener mensajes más específicos)
    if (!isLogin) { // Errores de registro primero
        switch (errorCode) {
            case 'email-already-in-use': return 'Este correo electrónico ya está registrado.';
            case 'weak-password': return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
        }
    } else { // Errores de login
        switch (errorCode) {
            case 'user-not-found': return 'No se encontró un usuario con este correo electrónico.';
            case 'wrong-password': return 'Contraseña incorrecta.';
        }
    }
    // Errores comunes a ambos
    switch (errorCode) {
        case 'invalid-email': return 'El formato del correo electrónico no es válido.';
        case 'user-disabled': return 'Este usuario ha sido deshabilitado.';
        case 'too-many-requests': return 'Demasiados intentos. Intenta de nuevo más tarde.';
        case 'network-request-failed': return 'Error de red. Verifica tu conexión a internet.';
        case 'account-exists-with-different-credential': return 'Ya existe una cuenta con este correo electrónico pero con un método de inicio de sesión diferente.';
        case 'popup-closed-by-user': return 'El proceso de inicio de sesión fue cancelado.';
        case 'unavailable': return 'Google Play Services no está disponible o necesita actualizarse.'; // Para Google
        default: return 'Ocurrió un error de autenticación ($errorCode).';
    }
  }


  @override
  Widget build(BuildContext context) {
    return AuthFormContainer(
      children: [
        Image.asset('assets/runilog.png', height: 100),
        const SizedBox(height: 20),
        Text("Crear Cuenta", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        AuthTextField(
          controller: emailController,
          label: 'Correo electrónico',
          keyboardType: TextInputType.emailAddress,
        ),
        AuthTextField(
          controller: passwordController,
          label: 'Contraseña (mín. 6 caracteres)',
          obscureText: obscureTextPassword,
          onToggleObscure: () => setState(() => obscureTextPassword = !obscureTextPassword),
        ),
        AuthTextField(
          controller: confirmController,
          label: 'Confirmar contraseña',
          obscureText: obscureTextConfirm,
          onToggleObscure: () => setState(() => obscureTextConfirm = !obscureTextConfirm),
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14), textAlign: TextAlign.center,),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isRegistering ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isRegistering
              ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.onPrimary))
              : const Text('Registrar'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isRegistering ? null : widget.onSwitch,
          child: const Text("¿Ya tienes cuenta? Inicia sesión aquí",
              style: TextStyle(fontSize: 15)),
        ),
      ],
    );
  }
}

class AuthFormContainer extends StatelessWidget {
  final List<Widget> children;
  const AuthFormContainer({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.black87), // Texto DENTRO del campo
        decoration: InputDecoration( // El estilo se hereda del InputDecorationTheme en MyApp
          labelText: label,
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey.shade600,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }
}