import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'auth_service.dart';

class PantallaPago extends StatefulWidget {
  final DateTime fecha;
  final String hora;
  final String cancha;

  const PantallaPago({
    super.key,
    required this.fecha,
    required this.hora,
    required this.cancha,
  });

  @override
  State<PantallaPago> createState() => _PantallaPagoState();
}

class _PantallaPagoState extends State<PantallaPago> {
  bool _isLoading = false;

  // --- PRECIOS Y SEÑA (CONFIGURACIÓN) ---
  // En una app real, estos valores vendrían de una base de datos o configuración remota.
  static const Map<String, double> _preciosCanchas = {
    'Cancha 1 - Fútbol 5': 5000.0,
    'Cancha 2 - Fútbol 8': 8000.0,
    'Cancha 3 - Fútbol 11': 12000.0,
  };
  static const double _porcentajeSena = 0.10; // 10%

  double get _montoTotal => _preciosCanchas[widget.cancha] ?? 0.0;
  double get _montoSena => _montoTotal * _porcentajeSena;

  /// Simula una llamada a un proveedor de pagos como Mercado Pago.
  /// En un futuro, aquí iría la integración real con el SDK de Mercado Pago.
  /// Devuelve `true` si el pago es exitoso, `false` si es rechazado.
  Future<bool> _simularPagoMercadoPago() async {
    setState(() {
      _isLoading = true;
    });

    // Simulamos una demora de red de 2 a 4 segundos.
    await Future.delayed(Duration(seconds: 2 + Random().nextInt(2)));

    // Simulamos una respuesta aleatoria (75% de éxito).
    final esExitoso = Random().nextDouble() < 0.75;

    // En un caso real, aquí recibirías un ID de transacción del proveedor de pago.
    return esExitoso;
  }

  /// Guarda la reserva en Firestore después de que el pago fue confirmado.
  Future<void> _guardarReservaConfirmada() async {
    final user = AuthService().currentUser;
    if (user == null) {
      // Esto no debería pasar si el usuario ya está en la app, pero es una buena práctica verificar.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reservas').add({
        'userId': user.uid,
        'userEmail': user.email,
        'fecha': Timestamp.fromDate(widget.fecha),
        'hora': widget.hora,
        'cancha': widget.cancha,
        'creadoEn': FieldValue.serverTimestamp(),
        // --- NUEVOS CAMPOS DE PAGO ---
        'seña_abonada': true,
        'monto_seña': _montoSena,
        'id_transaccion': 'sim_${DateTime.now().millisecondsSinceEpoch}', // ID de transacción simulado
      });

      // Muestra diálogo de éxito y navega hacia atrás.
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Pago Aprobado!'),
          content: const Text('Tu reserva ha sido confirmada con éxito.'),
          actions: [
            TextButton(
              onPressed: () {
                // Cierra el diálogo y la pantalla de pago, volviendo a la lista de reservas.
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); 
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la reserva: $e')),
      );
    }
  }

  void _iniciarProcesoDePago() async {
    final pagoExitoso = await _simularPagoMercadoPago();

    if (pagoExitoso) {
      await _guardarReservaConfirmada();
    } else {
      // Muestra diálogo de error.
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pago Rechazado'),
          content: const Text('No se pudo procesar el pago. Por favor, intenta de nuevo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Reserva y Pagar'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Detalle de la Reserva', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.sports_soccer), title: Text(widget.cancha)),
                    ListTile(leading: const Icon(Icons.calendar_today), title: Text(DateFormat('dd/MM/yyyy').format(widget.fecha))),
                    ListTile(leading: const Icon(Icons.access_time), title: Text('${widget.hora} hs')),
                    const Divider(height: 20),
                    ListTile(leading: const Icon(Icons.monetization_on_outlined), title: const Text('Monto Total'), trailing: Text('\$${_montoTotal.toStringAsFixed(2)}')),
                    ListTile(leading: const Icon(Icons.payment), title: Text('Seña (${(_porcentajeSena * 100).toInt()}%)'), trailing: Text('\$${_montoSena.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _iniciarProcesoDePago,
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.lock_open),
              label: _isLoading
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(width: 16), Text('Procesando pago...')])
                  : Text('Pagar Seña de \$${_montoSena.toStringAsFixed(2)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}