import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PantallaBusqueda extends StatefulWidget {
  const PantallaBusqueda({super.key});

  @override
  State<PantallaBusqueda> createState() => _PantallaBusquedaState();
}

class _PantallaBusquedaState extends State<PantallaBusqueda> {
  DateTime? fechaSeleccionada;
  String? canchaSeleccionada;
  List<QueryDocumentSnapshot>? resultados;
  bool isBuscandoPorFecha = true; // Para alternar entre búsqueda por fecha o cancha

  final List<String> canchas = [
    'Cancha 1 - Fútbol 5',
    'Cancha 2 - Fútbol 8',
    'Cancha 3 - Fútbol 11',
  ];

  Future<void> buscarPorFecha() async {
    if (fechaSeleccionada == null) return;

    try {
      final fechaInicio = DateTime(
        fechaSeleccionada!.year,
        fechaSeleccionada!.month,
        fechaSeleccionada!.day,
      );
      
      final fechaFin = fechaInicio.add(const Duration(days: 1));

      final QuerySnapshot resultado = await FirebaseFirestore.instance
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fechaFin))
          .orderBy('fecha')
          .orderBy('hora')
          .get();

      setState(() {
        resultados = resultado.docs;
      });
    } catch (e) {
      mostrarError('Error al buscar reservas: $e');
    }
  }

  Future<void> buscarPorCancha() async {
    if (canchaSeleccionada == null) return;

    try {
      // Consulta simplificada para reducir la necesidad de índices complejos
      final QuerySnapshot resultado = await FirebaseFirestore.instance
          .collection('reservas')
          .where('cancha', isEqualTo: canchaSeleccionada)
          .orderBy('fecha')
          .get();

      setState(() {
        resultados = resultado.docs;
      });
    } catch (e) {
      mostrarError('Error al buscar reservas: $e');
    }
  }

  void mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda de Reservas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Toggle para cambiar entre búsqueda por fecha o cancha
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Buscar por Fecha'),
                  icon: Icon(Icons.calendar_today),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Buscar por Cancha'),
                  icon: Icon(Icons.sports_soccer),
                ),
              ],
              selected: {isBuscandoPorFecha},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  isBuscandoPorFecha = newSelection.first;
                  resultados = null; // Limpiar resultados anteriores
                });
              },
            ),
            const SizedBox(height: 20),

            // Controles de búsqueda
            if (isBuscandoPorFecha) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2026), // Cambiado a 2026 para permitir fechas futuras
                  );
                  if (fecha != null) {
                    setState(() {
                      fechaSeleccionada = fecha;
                    });
                    buscarPorFecha();
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  fechaSeleccionada != null
                      ? DateFormat('dd/MM/yyyy').format(fechaSeleccionada!)
                      : 'Seleccionar fecha',
                ),
              ),
            ] else ...[
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
                  if (valor != null) {
                    buscarPorCancha();
                  }
                },
              ),
            ],

            const SizedBox(height: 20),

            // Resultados de la búsqueda
            Expanded(
              child: resultados == null
                  ? const Center(
                      child: Text('Realiza una búsqueda'),
                    )
                  : resultados!.isEmpty
                      ? const Center(
                          child: Text('No se encontraron reservas'),
                        )
                      : ListView.builder(
                          itemCount: resultados!.length,
                          itemBuilder: (context, index) {
                            final reserva = resultados![index].data() as Map<String, dynamic>;
                            final fecha = (reserva['fecha'] as Timestamp).toDate();
                            
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.sports_soccer),
                                title: Text(reserva['cancha']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}'),
                                    Text('Hora: ${reserva['hora']} hs'),
                                    Text('Usuario: ${reserva['userEmail']}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}