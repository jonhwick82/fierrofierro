import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class Pantalla2 extends StatefulWidget {
  final String userEmail;
  final String userName;

  const Pantalla2({Key? key, required this.userEmail, required this.userName}) : super(key: key);

  @override
  State<Pantalla2> createState() => _Pantalla2State();
}

class _Pantalla2State extends State<Pantalla2> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();

  // Crear un registro
  Future<void> crearUsuario(String nombre, int edad) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').add({
        'nombre': nombre,
        'edad': edad,
        'creadoEn': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario creado exitosamente')),
      );
    } catch (e) {
      print('Error al crear usuario: $e');
    }
  }

  // Leer registros
  Stream<QuerySnapshot> leerUsuarios() {
    return FirebaseFirestore.instance.collection('usuarios').snapshots();
  }

  // Actualizar un registro
  Future<void> actualizarUsuario(String id, String nuevoNombre, int nuevaEdad) async {
    try {
      // Verifica que el ID no esté vacío
      if (id.isEmpty) {
        throw Exception('El ID del documento no puede estar vacío');
      }

      // Actualiza el documento en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(id).update({
        'nombre': nuevoNombre,
        'edad': nuevaEdad,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado exitosamente')),
      );
    } catch (e) {
      print('Error al actualizar usuario: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar usuario: $e')),
      );
    }
  }

  // Eliminar un registro
  Future<void> eliminarUsuario(String id) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado exitosamente')),
      );
    } catch (e) {
      print('Error al eliminar usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CRUD - Bienvenido ${widget.userName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              // Cierra la sesión de Firebase y Google
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();

              // Redirige al usuario a la pantalla de inicio de sesión
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage(title: 'Login con Gmail')),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _edadController,
              decoration: const InputDecoration(labelText: 'Edad'),
              keyboardType: TextInputType.number,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final nombre = _nombreController.text;
              final edad = int.tryParse(_edadController.text) ?? 0;
              crearUsuario(nombre, edad);
            },
            child: const Text('Crear Usuario'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: leerUsuarios(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error al cargar los datos');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final data = snapshot.data!;
                return ListView(
                  children: data.docs.map((doc) {
                    final usuario = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(usuario['nombre']),
                      subtitle: Text('Edad: ${usuario['edad']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              // Llena los controladores con los datos actuales
                              _nombreController.text = usuario['nombre'];
                              _edadController.text = usuario['edad'].toString();

                              // Muestra un diálogo para editar los datos
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Editar Usuario'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: _nombreController,
                                          decoration: const InputDecoration(labelText: 'Nombre'),
                                        ),
                                        TextField(
                                          controller: _edadController,
                                          decoration: const InputDecoration(labelText: 'Edad'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final nuevoNombre = _nombreController.text;
                                          final nuevaEdad = int.tryParse(_edadController.text) ?? 0;

                                          // Llama a la función de actualización con el ID del documento
                                          actualizarUsuario(doc.id, nuevoNombre, nuevaEdad);

                                          // Cierra el diálogo
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Guardar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => eliminarUsuario(doc.id),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  final String title;

  const LoginPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: const Text('Pantalla de inicio de sesión'),
      ),
    );
  }
}