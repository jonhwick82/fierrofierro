import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// 1. Importar la implementación específica de Android
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:permission_handler/permission_handler.dart'; // 1. Importar el manejador de permisos

class PantallaCheckoutMP extends StatefulWidget {
  final String checkoutUrl;

  const PantallaCheckoutMP({
    super.key,
    required this.checkoutUrl,
  });

  @override
  State<PantallaCheckoutMP> createState() => _PantallaCheckoutMPState();
}

class _PantallaCheckoutMPState extends State<PantallaCheckoutMP> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // 2. Crear el controlador de WebView con configuración específica de Android
    late final PlatformWebViewControllerCreationParams params;
    params = const PlatformWebViewControllerCreationParams();
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    // 3. Configurar el "puente" de permisos para la cámara
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setOnPlatformPermissionRequest((PlatformWebViewPermissionRequest request) async {
        // Primero, pedimos el permiso a nivel de la app
        final status = await Permission.camera.request();
        
        // Si el usuario concede el permiso a la app...
        if (status.isGranted) {
          // ...se lo concedemos también a la página web.
          await request.grant();
        } else {
          // Si no, se lo negamos.
          await request.deny();
        }
      });
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Mobile Safari/537.36");
    // --- LIMPIEZA AGRESIVA Y DEFINITIVA ---
    // Limpiamos cookies y caché DESPUÉS de crear el controlador.
    await WebViewCookieManager().clearCookies();
    await controller.clearCache();
    
    controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // 1. Detectamos si la URL es una de nuestras URLs de Deep Link de retorno.
            if (request.url.startsWith('reservasapp://payment/')) {
              final uri = Uri.parse(request.url);
              String status = 'unknown';

              // Extraemos el estado directamente de la ruta de la URL.
              if (uri.pathSegments.contains('success')) {
                status = 'approved';
              } else if (uri.pathSegments.contains('pending')) {
                status = 'pending';
              } else if (uri.pathSegments.contains('failure')) {
                status = 'failure';
              }
              
              Navigator.of(context).pop(status);
              
              return NavigationDecision.prevent;
            }

            // 2. Si la URL NO es una página web (ej. mercadopago://), la bloqueamos.
            if (!request.url.startsWith('http://') && !request.url.startsWith('https://')) {
              // Esto evita que el WebView intente abrir la app de Mercado Pago y falle si no está instalada.
              return NavigationDecision.prevent;
            }

            // 3. Para cualquier otra URL http o https, permitimos la navegación normal.
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Pago'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: Stack(
        children: [
          // Solo muestra el WebView si el controlador ya fue inicializado.
          if (_controller != null)
            WebViewWidget(controller: _controller!),
          // Muestra el indicador de carga mientras el controlador se prepara o la página carga.
          if (_isLoading || _controller == null)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}