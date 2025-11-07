import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/back_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeleccionAccionScreen extends StatelessWidget {
  const SeleccionAccionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Visita'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Entrada (por código de casa)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/seleccion-condominio');
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: const Text('Salida (mostrar QR de casa)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  if (!context.mounted) return;

                  final casa = prefs.getString('casa');
                  final condominio = prefs.getString('condominio');

                  if (casa != null && condominio != null) {
                    context.push('/qr-casa', extra: {
                      'casa': casa,
                      'condominio': condominio,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Primero debes ingresar correctamente a una casa.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
