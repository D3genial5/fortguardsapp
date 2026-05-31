import 'package:flutter/material.dart';
import '../services/secure_screen_service.dart';

/// Envuelve [child] y activa la protección anti-captura de pantalla
/// (`SecureScreenService`) mientras el widget está montado. Se usa en pantallas
/// con información sensible como los QR de acceso.
class SecureScreen extends StatefulWidget {
  final Widget child;

  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    SecureScreenService.enable();
  }

  @override
  void dispose() {
    SecureScreenService.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
