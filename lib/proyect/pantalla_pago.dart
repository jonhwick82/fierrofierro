import 'dart:convert'; // Necesario para decodificar la respuesta del backend.
import 'package:http/http.dart' as http; // Para hacer la llamada al backend.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'pantalla_checkout_mp.dart'; // Importamos la nueva pantalla para el WebView.

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
    'Cancha 1 - Fútbol 5': 500.0,
    'Cancha 2 - Fútbol 8': 800.0,
    'Cancha 3 - Fútbol 11': 1200.0,
  };
  static const double _porcentajeSena = 0.10; // 10%

  double get _montoTotal => _preciosCanchas[widget.cancha] ?? 0.0;
  double get _montoSena => _montoTotal * _porcentajeSena;

  /// **PASO CLAVE: Crear la preferencia de pago en tu backend.**
  /// Esta función llama a un backend (que tú crearías, por ej. con Firebase Functions)
  /// para generar la preferencia de pago en Mercado Pago de forma segura.
  /// Devuelve la URL de checkout (`init_point`).
  Future<Map<String, dynamic>?> _crearPreferenciaMercadoPago() async {
    setState(() {
      _isLoading = true;
    });

    // --- LLAMADA REAL AL BACKEND (FIREBASE FUNCTION) ---

    // IMPORTANTE: Reemplaza esta URL por la URL de tu Firebase Function que obtuviste al desplegar.
    // ¡CORRECCIÓN! Esta es la URL que te dio la terminal al desplegar la función.
    // Pega aquí la URL que copiaste en el paso anterior.
    final url = Uri.parse('https://us-central1-ruso-72591.cloudfunctions.net/createPreference');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': 'Seña reserva: ${widget.cancha}',
          'description': 'Reserva para el ${DateFormat('dd/MM/yyyy').format(widget.fecha)} a las ${widget.hora}',
          'quantity': 1,
          'unitPrice': _montoSena,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // El backend devuelve el 'init_point', 'sandbox_init_point' y el 'id'.
        // Capturamos todos los datos que nos envía el backend.
        return data;
      } else {
        // Si el backend falla, muestra un error.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error del servidor: ${response.body}')),
        );
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión al crear el pago: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

  }

  /// Guarda la reserva en Firestore después de que el pago fue confirmado.
  Future<void> _guardarReservaConfirmada(String idPreferencia) async {
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
        'id_preferencia_mp': idPreferencia, // ID de la preferencia real de Mercado Pago
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
    // 1. Llama a tu backend para obtener la URL de pago.
    final Map<String, dynamic>? preferencia = await _crearPreferenciaMercadoPago();

    if (preferencia != null && mounted) {
      final String initPoint = preferencia['init_point']; // Para pagos reales, siempre usamos init_point
      final String preferenciaId = preferencia['id'];

      // 2. Navega a la pantalla del WebView para que el usuario pague.
      final resultadoPago = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaCheckoutMP(checkoutUrl: initPoint),
        ),
      );
      // 3. Procesa el resultado del pago.
      if (resultadoPago == 'approved') {
        await _guardarReservaConfirmada(preferenciaId);
      } else if (resultadoPago == 'pending') {
        // Opcional: Manejar pagos pendientes.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pago está pendiente de confirmación.')),
        );
        Navigator.of(context).pop();
      } else {
        // Manejar pago fallido o cancelado.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pago fue rechazado o cancelado.')),
        );
      }
    }
    // Si checkoutUrl es null, el error ya se mostró en _crearPreferenciaMercadoPago.
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