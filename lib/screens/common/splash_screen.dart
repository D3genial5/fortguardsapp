import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla de bienvenida que se muestra al abrir la app y redirige al flujo
/// principal (`/`) tras una breve pausa.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      // Registro de visitante = una sola vez por dispositivo. Si ya se registró
      // y aceptó términos, se salta el formulario y va directo al acceso.
      final prefs = await SharedPreferences.getInstance();
      final registrado = prefs.getBool('visitante_registrado') ?? false;
      final terminos = prefs.getBool('terminos_aceptados') ?? false;
      if (!mounted) return;
      if (registrado && terminos) {
        context.go('/acceso-general');
      } else {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/fortguard_logo.png',
              width: 160,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shield_rounded,
                size: 96,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
