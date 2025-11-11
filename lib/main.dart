import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:io' show InternetAddress, SocketException, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart'; // 1. Importar el paquete de audio
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'proyect/auth_service.dart';
import 'proyect/pantalla_reservas.dart';
import 'pantalla_registro.dart';
//
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // mover esto antes de cargar el .env

  // Intentar cargar el .env desde varias ubicaciones comunes
  final List<String> posiblesRutas = [
    'functions/.env.ruso-72591',
    '.env.ruso-72591',
    '.env',
  ];
  bool cargado = false;
  for (final ruta in posiblesRutas) {
    try {
      // Verifica existencia rápida antes de intentar cargar (evita excepción larga)
      if (await File(ruta).exists()) {
        await dotenv.load(fileName: ruta);
        cargado = true;
        print('Cargado .env desde: $ruta');
        break;
      }
    } catch (_) {
      // continue
    }
  }
  if (!cargado) {
    print('No se encontró el archivo .env en las rutas comprobadas: $posiblesRutas');
  }
  
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    } else {
      final options = FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? (throw Exception('FIREBASE_API_KEY no está definido')),
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? (throw Exception('FIREBASE_PROJECT_ID no está definido')),
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID'] ?? (throw Exception('FIREBASE_APP_ID no está definido')),
      );

      await Firebase.initializeApp(options: options);
    }
    print('Firebase inicializado correctamente');
  } catch (e) {
    print('Error al inicializar Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BIG CANCHAS - Reserva tu cancha',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFFFF9800),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
      ),
      home: const LoginPage(title: 'Ingreso a Futbol App'),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _hasInternetConnection = true;
  // Controladores para el login con email/password
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 2. Crear una instancia del reproductor de audio
  final _audioPlayer = AudioPlayer();

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternetConnection = true;
        });
      }
    } on SocketException catch (_) {
      setState(() {
        _hasInternetConnection = false;
      });
    }
  }

  // 3. Función para iniciar la música
  Future<void> _playBackgroundMusic() async {
    // Configura el reproductor para que la música se repita en bucle
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Reproduce el archivo desde los assets
    await _audioPlayer.play(AssetSource('OPUS.mp3'));
  }

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _playBackgroundMusic(); // Inicia la música cuando la pantalla se carga

    // Precachear el sticker animado para evitar parpadeos al empezar a reproducirlo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/cdam.webp'), context);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _audioPlayer.dispose(); // 4. Detiene y libera el reproductor al salir de la pantalla
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        // La lógica para obtener el rol es la misma que con Google
        await _fetchUserRoleAndNavigate(user);
      } else {
        throw Exception('No se pudo obtener información del usuario');
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Error al iniciar sesión.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Correo o contraseña incorrectos.';
      }
      mostrarError(message);
    } catch (e) {
      mostrarError('Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PantallaRegistro()),
    );
  }
  
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });
    
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
        signInOption: SignInOption.standard, // Añadir esta línea
      );

      // Asegurarse de que no hay sesiones activas
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      // Manejar el inicio de sesión
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn()
          .timeout(
            const Duration(minutes: 1),
            onTimeout: () => throw TimeoutException('Tiempo de espera agotado'),
          );

      if (googleUser == null) {
        throw Exception('Inicio de sesión cancelado por el usuario');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      final User? user = userCredential.user;
      
      if (user != null) {
        await _fetchUserRoleAndNavigate(user);
      } else {
         throw Exception('No se pudo obtener información del usuario');
      }
    } catch (e) {
      if (e.toString().contains('Selección de cuenta cancelada')) {
        mostrarError('Se canceló la selección de cuenta');
      } else {
        mostrarError('Error al iniciar sesión: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Método reutilizable para obtener el rol del usuario y navegar.
  Future<void> _fetchUserRoleAndNavigate(User user) async {
    // 1. Buscar el usuario en la colección 'usuarios' por su UID.
    final userDocRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
    final userDoc = await userDocRef.get();

    String userRole;
    String userName;

    // 2. Si el usuario no existe en Firestore (caso raro, ej. login con Google por 1ra vez), lo creamos.
    if (!userDoc.exists) {
      // --- LÓGICA DE ADMINISTRADOR POR DEFECTO ---
      // Si el email del nuevo usuario es el del administrador designado, se le asigna el rol 'admin'.
      if (user.email == 'reichelj82@gmail.com') {
        userRole = 'admin';
      } else {
        userRole = 'usuario'; // Rol por defecto para otros usuarios
      }
      userName = user.displayName ?? 'Jugador';
      await userDocRef.set({
        'email': user.email,
        'displayName': userName,
        'rol': userRole,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } else {
      // 3. Si el usuario ya existe, obtenemos sus datos.
      // Verificamos si es el admin designado para asegurar que siempre tenga el rol correcto.
      if (user.email == 'reichelj82@gmail.com') {
        userRole = 'admin';
      } else {
        userRole = userDoc.data()?['rol'] ?? 'usuario';
      }
      userName = userDoc.data()?['displayName'] ?? user.displayName ?? 'Jugador';
    }

    // 4. Guardar el usuario y su rol en nuestro AuthService.
    final appUser = AppUser(uid: user.uid, email: user.email ?? '', name: userName, role: userRole);
    AuthService().setUser(appUser);

    if (!mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PantallaReservas()),
    );
  }

  void mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Igualar el fondo al color blanco del sticker para que no se note el recuadro
        color: Colors.white,
         child: Center(
           child: Card(
             margin: const EdgeInsets.all(32),
            elevation: 0, // opcional: 0 quita la sombra del recuadro
            color: Colors.transparent, // hace que la Card no dibuje un fondo blanco
             child: SingleChildScrollView( // <--- WIDGET AÑADIDO PARA SOLUCIONAR EL OVERFLOW
               child: Form(
                key: _formKey,
                child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Fondo blanco explícito y gaplessPlayback evita parpadeos entre frames
                    Container(
                      color: Colors.white,
                      child: Image.asset(
                        'assets/cdam.webp',
                        height: 120,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                    const Text(
                      '¡BIG CANCHAS!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reserva tu cancha de fútbol',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value!.isEmpty ? 'Ingresa tu correo' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                      validator: (value) => value!.isEmpty ? 'Ingresa tu contraseña' : null,
                    ),
                    const SizedBox(height: 20),


                    if (!_hasInternetConnection)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'Sin conexión a Internet',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _isLoading || !_hasInternetConnection ? null : _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Iniciar Sesión'),
                    ),
                    const SizedBox(height: 12),
                    const Text("o"),
                    const SizedBox(height: 12),


                    ElevatedButton.icon(
                      onPressed: _isLoading || !_hasInternetConnection ? null : _signInWithGoogle,
                      icon: const Icon(Icons.sports), // Ícono de Google (puedes cambiarlo)
                      label: Text(
                        _isLoading ? 'Ingresando...' : 'Ingresar con Google',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _isLoading ? null : _navigateToRegister,
                      child: const Text('¿No tienes una cuenta? Regístrate aquí'),
                    )
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
