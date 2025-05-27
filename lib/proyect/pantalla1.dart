import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/main.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Pantalla1 extends StatefulWidget {
  final String userEmail;
  final String userName;
  
  const Pantalla1({
    super.key, 
    required this.userEmail,
    required this.userName,
  });

  @override
  State<Pantalla1> createState() => _Pantalla1State();
}

class _Pantalla1State extends State<Pantalla1> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  
  Future<void> _enviarDatosAFirebase() async {
    // Verificar que los campos no estén vacíos
    if (_nombreController.text.isEmpty || _edadController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos')),
      );
      return;
    }
    
    try {
      // Convertir la edad a número
      int edad = int.parse(_edadController.text);
      
      // Enviar los datos a Firestore
      await FirebaseFirestore.instance.collection('datos').add({
        'nombre': _nombreController.text,
        'edad': edad,
        'email': widget.userEmail,
        'fechaRegistro': FieldValue.serverTimestamp(),
      });
      
      // Mostrar mensaje de éxito
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos enviados correctamente')),
      );
      
      // Limpiar los campos después de enviar
      _nombreController.clear();
      _edadController.clear();
    } catch (e) {
      // Mostrar mensaje de error
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar datos: $e')),
      );
    }
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    
    // Regresar a la pantalla de login
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginPage(title: 'Login con Gmail'),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Datos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, ${widget.userName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Email: ${widget.userEmail}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Complete los siguientes datos:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _edadController,
              decoration: const InputDecoration(
                labelText: 'Edad',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _enviarDatosAFirebase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'Enviar Registro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}