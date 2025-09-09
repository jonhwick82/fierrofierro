import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_1/main.dart';
import 'pantalla_busqueda.dart';


class PantallaReservas extends StatefulWidget {
  final String userEmail;
  final String userName;

  const PantallaReservas({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<PantallaReservas> createState() => _PantallaReservasState();
}

class _PantallaReservasState extends State<PantallaReservas> {
  DateTime? fechaSeleccionada;
  String? horaSeleccionada;
  String? canchaSeleccionada;

  final List<String> horarios = [
    '09:00', '10:00', '11:00', '12:00', '13:00',
    '14:00', '15:00', '16:00', '17:00', '18:00',
    '19:00', '20:00', '21:00', '22:00'
  ];

  final List<String> canchas = [
    'Cancha 1 - Fútbol 5',
    'Cancha 2 - Fútbol 8',
    'Cancha 3 - Fútbol 11',
  ];

  late Stream<QuerySnapshot> _reservasStream;

  @override
  void initState() {
    super.initState();
    _inicializarStream();
  }

  void _inicializarStream() {
    try {
      _reservasStream = FirebaseFirestore.instance
          .collection('reservas')
          .where('userEmail', isEqualTo: widget.userEmail)
          .orderBy('fecha', descending: true)
          .snapshots();
    } catch (e) {
      setState(() {
        // _error = 'Error al cargar las reservas: $e';
        // _isLoading = false;
      });
    }
  }

  Future<void> realizarReserva() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes estar autenticado para realizar una reserva')),
      );
      return;
    }

    if (fechaSeleccionada == null || horaSeleccionada == null || canchaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Ajustar la fecha seleccionada a medianoche para evitar problemas de zona horaria
    final fechaAjustada = DateTime(
      fechaSeleccionada!.year,
      fechaSeleccionada!.month,
      fechaSeleccionada!.day,
    );

    // Verificar disponibilidad antes de crear la reserva
    final bool disponible = await verificarDisponibilidad(
      fechaAjustada,
      horaSeleccionada!,
      canchaSeleccionada!,
    );

    if (!disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lo sentimos, este horario ya no está disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final reservaData = {
        'userId': user.uid,
        'userEmail': user.email, // Agregar el email del usuario
        'fecha': Timestamp.fromDate(fechaAjustada), // Convertir DateTime a Timestamp
        'hora': horaSeleccionada,
        'cancha': canchaSeleccionada,
        'estado': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('reservas')
          .add(reservaData);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reserva realizada con éxito!'),
          backgroundColor: Color(0xFF1B5E20),
        ),
      );

      setState(() {
        fechaSeleccionada = null;
        horaSeleccionada = null;
        canchaSeleccionada = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al realizar la reserva: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> verificarDisponibilidad(DateTime fecha, String hora, String cancha) async {
    try {
      final QuerySnapshot resultado = await FirebaseFirestore.instance
          .collection('reservas')
          .where('fecha', isEqualTo: Timestamp.fromDate(
            DateTime(fecha.year, fecha.month, fecha.day),
          ))
          .where('hora', isEqualTo: hora)
          .where('cancha', isEqualTo: cancha)
          .get();

      return resultado.docs.isEmpty;
    } catch (e) {
      print('Error al verificar disponibilidad: $e');
      return false;
    }
  }

  Future<List<String>> obtenerHorariosDisponibles(DateTime fecha, String? canchaSeleccionada) async {
    if (canchaSeleccionada == null) return [];
    
    List<String> horariosDisponibles = List.from(horarios);
    
    try {
      final QuerySnapshot reservas = await FirebaseFirestore.instance
          .collection('reservas')
          .where('fecha', isEqualTo: Timestamp.fromDate(
            DateTime(fecha.year, fecha.month, fecha.day),
          ))
          .where('cancha', isEqualTo: canchaSeleccionada)
          .get();

      for (var doc in reservas.docs) {
        final data = doc.data() as Map<String, dynamic>;
        horariosDisponibles.remove(data['hora']);
      }
      
      return horariosDisponibles;
    } catch (e) {
      print('Error al obtener horarios disponibles: $e');
      return [];
    }
  }

  Future<List<String>> obtenerCanchasDisponibles(DateTime fecha, String hora) async {
    List<String> canchasDisponibles = List.from(canchas);
    
    try {
      final QuerySnapshot reservas = await FirebaseFirestore.instance
          .collection('reservas')
          .where('fecha', isEqualTo: Timestamp.fromDate(
            DateTime(fecha.year, fecha.month, fecha.day),
          ))
          .where('hora', isEqualTo: hora)
          .get();

      for (var doc in reservas.docs) {
        final data = doc.data() as Map<String, dynamic>;
        canchasDisponibles.remove(data['cancha']);
      }
      
      return canchasDisponibles;
    } catch (e) {
      print('Error al obtener canchas disponibles: $e');
      return [];
    }
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginPage(title: 'Ingreso a Futbol App'),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Reservas - ${widget.userName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PantallaBusqueda(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[300], // Añadido color de fondo gris claro
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Cambiado a center
                  children: [
                    Text(
                      '¡Bienvenido, ${widget.userName}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center, // Añadido para centrar el texto
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.userEmail,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center, // Añadido para centrar el email
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.grey[200], // Añadido color de fondo gris claro
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nueva Reserva',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (fecha != null) {
                          setState(() {
                            fechaSeleccionada = fecha;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        fechaSeleccionada != null
                            ? '${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}'
                            : 'Seleccionar fecha',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: canchaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar cancha',
                        border: OutlineInputBorder(),
                      ),
                      items: canchas.map((cancha) {
                        return DropdownMenuItem(
                          value: cancha,
                          child: Text(cancha),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        setState(() {
                          canchaSeleccionada = valor;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<String>>(
                      future: fechaSeleccionada != null && canchaSeleccionada != null
                          ? obtenerHorariosDisponibles(fechaSeleccionada!, canchaSeleccionada)
                          : Future.value([]),
                      builder: (context, snapshot) {
                        return DropdownButtonFormField<String>(
                          value: horaSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar hora',
                            border: OutlineInputBorder(),
                          ),
                          items: (snapshot.data ?? []).map((hora) {
                            return DropdownMenuItem(
                              value: hora,
                              child: Text('$hora hs'),
                            );
                          }).toList(),
                          onChanged: snapshot.data?.isEmpty ?? true
                              ? null
                              : (valor) {
                                  setState(() {
                                    horaSeleccionada = valor;
                                  });
                                },
                          hint: Text(snapshot.data?.isEmpty ?? true
                              ? 'No hay horarios disponibles'
                              : 'Seleccione un horario'),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: realizarReserva,
                      icon: const Icon(Icons.sports_soccer),
                      label: const Text('Realizar Reserva'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reservas Realizadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _reservasStream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar las reservas: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No tienes reservas realizadas'),
                  );
                }

                final reservas = snapshot.data!.docs;

                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: reservas.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final reserva = reservas[index].data() as Map<String, dynamic>;
                      final fecha = (reserva['fecha'] as Timestamp).toDate();
                      
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.sports_soccer,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          title: Text(
                            reserva['cancha'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${fecha.day}/${fecha.month}/${fecha.year}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                'Hora: ${reserva['hora']} hs',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Color.fromARGB(255, 190, 45, 1), // Cambiado de Colors.red a Colors.deepOrange
                            ),
                            onPressed: () async {
                              // Mostrar diálogo de confirmación
                              final confirmar = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancelar reserva'),
                                  content: const Text('¿Estás seguro que deseas cancelar esta reserva?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Sí'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirmar == true) {
                                await reservas[index].reference.delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reserva cancelada exitosamente'),
                                    backgroundColor: Color(0xFF1B5E20),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


}