import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Ruta considerada "inicio" del flujo: desde aquí el botón atrás sale de la
/// app (con confirmación), en vez de seguir navegando.
const String _rutaInicio = '/acceso-general';

/// Widget reutilizable para manejar el botón "Atrás" de Android.
/// Envuelve cualquier pantalla para controlar el comportamiento del botón físico.
///
/// Comportamiento:
///  - Si hay historial, vuelve a la pantalla anterior.
///  - Si no hay historial y no estamos en el inicio, va al inicio.
///  - Si ya estamos en el inicio, pide un segundo toque para salir (patrón
///    estándar de Android) en vez de dejar la pantalla sin responder.
class BackHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback? onBackPressed; // Callback opcional personalizado

  const BackHandler({
    super.key,
    required this.child,
    this.onBackPressed,
  });

  @override
  State<BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<BackHandler> {
  DateTime? _ultimoIntentoSalida;

  void _manejarAtras() {
    // Callback personalizado tiene prioridad
    if (widget.onBackPressed != null) {
      widget.onBackPressed!();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    // Sin historial: si no estamos en el inicio, ir al inicio.
    final rutaActual = GoRouterState.of(context).matchedLocation;
    if (rutaActual != _rutaInicio) {
      context.go(_rutaInicio);
      return;
    }

    // Ya en el inicio: doble toque para salir.
    final ahora = DateTime.now();
    final reciente = _ultimoIntentoSalida != null &&
        ahora.difference(_ultimoIntentoSalida!) < const Duration(seconds: 2);

    if (reciente) {
      SystemNavigator.pop();
      return;
    }

    _ultimoIntentoSalida = ahora;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Presiona atrás de nuevo para salir'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Siempre interceptamos el botón atrás
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _manejarAtras();
      },
      child: widget.child,
    );
  }
}
