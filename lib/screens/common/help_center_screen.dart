import 'package:flutter/material.dart';
import '../../widgets/back_handler.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Centro de ayuda'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('Preguntas frecuentes'),
              subtitle: Text('Resuelve dudas comunes sobre el uso de FortGuards.'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.support_agent),
              title: Text('Soporte'),
              subtitle: Text('Escríbenos a soporte@fortguards.com'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
