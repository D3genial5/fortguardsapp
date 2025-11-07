import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Widget reutilizable para manejar el botón "Atrás" de Android
/// Envuelve cualquier pantalla para controlar el comportamiento del botón físico
class BackHandler extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBackPressed; // Callback opcional personalizado

  const BackHandler({
    super.key,
    required this.child,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Siempre interceptamos el botón atrás
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // Si ya se hizo pop del sistema, no hacer nada
        if (didPop) return;
        
        // Si hay un callback personalizado, úsalo
        if (onBackPressed != null) {
          onBackPressed!();
          return;
        }

        // Verificar si podemos hacer pop en el router (dinámicamente)
        final router = GoRouter.of(context);
        if (router.canPop()) {
          // Si hay historial, navegar hacia atrás
          router.pop();
        }
        // Si no hay historial, no hacer nada (no cerrar la app automáticamente)
        // Para cerrar la app, el usuario debe presionar atrás de nuevo
      },
      child: child,
    );
  }
}
