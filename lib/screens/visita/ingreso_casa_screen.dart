import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/codigo_casa_util.dart';
import '../../widgets/back_handler.dart';

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
  bool _autoVerificando = false;

  // Ya no necesitamos cargar el código, lo verificamos directamente en Firestore
  // con el método verificarCodigo

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verificarCodigo() async {
    if (_autoVerificando) return;
    if (_codigoController.text.trim().length < 3) return;
    setState(() {
      _autoVerificando = true;
    });
    
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
      await prefs.setBool('qr_pendiente', true);
      
      // GENERAR SESSION ID ÚNICO para ligar entrada y salida
      final sessionId = '${widget.condominio}_${widget.casaNumero}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('session_id', sessionId);
      
      // GUARDAR DATOS DEL VISITANTE EN FIRESTORE para que el guardia los vea
      final nombre = prefs.getString('visitante_nombre');
      final ci = prefs.getString('visitante_ci');
      final fotoFrente = prefs.getString('visitante_foto_frente');
      final fotoReverso = prefs.getString('visitante_foto_reverso');
      
      if (nombre != null && ci != null) {
        try {
          await FirebaseFirestore.instance
              .collection('condominios')
              .doc(widget.condominio)
              .collection('casas')
              .doc(widget.casaNumero.toString())
              .set({
            'ultimoVisitanteNombre': nombre,
            'ultimoVisitanteCI': ci,
            'ultimoVisitanteFotoFrente': fotoFrente,
            'ultimoVisitanteFotoReverso': fotoReverso,
            'ultimoAccesoFecha': FieldValue.serverTimestamp(),
            'sessionId': sessionId,
          }, SetOptions(merge: true));
        } catch (e) {
          // Silencioso, no bloquear el flujo
        }
      }

      _mostrarQR();
    } else {
      setState(() {
        _codigoInvalido = true;
      });
    }
    
    if (mounted) {
      setState(() {
        _autoVerificando = false;
      });
    }
  }

  void _mostrarQR() {
    context.push('/qr-casa', extra: {
      'casa': 'Casa ${widget.casaNumero}',
      'condominio': widget.condominio,
      'forzarCodigoCasa': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
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
                    maxLength: 3,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (value) {
                      if (value.length < 3 && _codigoInvalido) {
                        setState(() {
                          _codigoInvalido = false;
                        });
                      }
                      if (value.length == 3) {
                        FocusScope.of(context).unfocus();
                        _verificarCodigo();
                      }
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.pin),
                      labelText: 'Código de la casa',
                      counterText: '',
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
                    onPressed: _autoVerificando ? null : _verificarCodigo,
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(_autoVerificando ? 'Verificando...' : 'Ver QR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
