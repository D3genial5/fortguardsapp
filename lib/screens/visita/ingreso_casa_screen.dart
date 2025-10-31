import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/codigo_casa_util.dart';

class IngresoCasaScreen extends StatefulWidget {
  final int casaNumero;
  final String condominio;

  const IngresoCasaScreen({
    super.key,
    required this.casaNumero,
    required this.condominio,
  });

  @override
  State<IngresoCasaScreen> createState() => _IngresoCasaScreenState();
}

class _IngresoCasaScreenState extends State<IngresoCasaScreen> {
  final _codigoController = TextEditingController();
  bool _codigoInvalido = false;

  // Ya no necesitamos cargar el código, lo verificamos directamente en Firestore
  // con el método verificarCodigo

  @override
  void initState() {
    super.initState();
  }

  void _verificarCodigo() async {
    final esValido = await CodigoCasaUtil.verificarCodigo(
      codigo: _codigoController.text,
      condominioId: widget.condominio,
      casaNumero: widget.casaNumero,
    );
    
    if (esValido) {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      await prefs.setString('casa', 'Casa ${widget.casaNumero}');
      await prefs.setString('condominio', widget.condominio);

      _mostrarQR(); // función separada elimina la advertencia
    } else {
      setState(() {
        _codigoInvalido = true;
      });
    }
  }

  void _mostrarQR() {
    context.push('/qr-casa', extra: {
      'casa': 'Casa ${widget.casaNumero}',
      'condominio': widget.condominio,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Código - Casa ${widget.casaNumero}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline_rounded),
                      SizedBox(width: 8),
                      Text('Ingrese el código de la casa', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codigoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.pin),
                      labelText: 'Código de la casa',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_codigoInvalido)
                    const Text(
                      'Código incorrecto',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _verificarCodigo,
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Ver QR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
