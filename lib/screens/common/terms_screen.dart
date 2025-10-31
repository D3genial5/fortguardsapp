import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y condiciones'),
        leading: const BackButton(),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            'Al utilizar FortGuards aceptas nuestras políticas de uso y privacidad. ' 
            'El sistema facilita el control de acceso, generación de códigos y notificaciones. ' 
            'Los datos son tratados conforme a la normativa vigente.',
          ),
        ),
      ),
    );
  }
}
