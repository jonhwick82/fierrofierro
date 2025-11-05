import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'proyect/auth_service.dart';
import 'proyect/pantalla_reservas.dart';
import 'pantalla_registro.dart';
//
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC_26YE7HovI7bdqcWO4ixcVgth9gzzNNo",
          authDomain: "ruso-72591.firebaseapp.com",
          projectId: "ruso-72591",
          storageBucket: "ruso-72591.appspot.com",
          messagingSenderId: "481455410667",
          appId: "1:481455410667:web:XXXXXXXXXXXXX" // Reemplaza con tu appId web
        ),
      );
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
      title: 'Futbol App - Reserva tu cancha',
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

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
        decoration: const BoxDecoration(
          color: Color(0xFF1B5E20), // Color verde oscuro de fondo
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            elevation: 8,
            
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.9),
            child: SingleChildScrollView( // <--- WIDGET AÑADIDO PARA SOLUCIONAR EL OVERFLOW
              child: Form(
                key: _formKey,
                child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.sports_soccer,
                      size: 64,
                      color: Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '¡Bienvenido a Futbol App!',
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
