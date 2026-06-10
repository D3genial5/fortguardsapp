import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/codigo_casa_util.dart';
import '../../widgets/back_handler.dart';
import '../../services/secure_storage_service.dart';
import '../../services/qr_local_service.dart';
import '../../models/qr_local_model.dart';

class IngresoCasaScreen extends StatefulWidget {
  final String casaNumero;
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

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
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
      final nombre = await SecureStorageService.getVisitanteNombre();
      final ci = await SecureStorageService.getVisitanteCi();
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

      // Persistir el QR localmente para que aparezca en "Mis QRs".
      // Leemos el doc de la casa para conocer la expiración y usos vigentes.
      try {
        final casaDoc = await FirebaseFirestore.instance
            .collection('condominios')
            .doc(widget.condominio)
            .collection('casas')
            .doc(widget.casaNumero.toString())
            .get();
        final data = casaDoc.data();
        final expiraTs = data?['codigoExpira'] as Timestamp?;
        final usosRestantes = data?['codigoUsos'] as int? ?? 1;

        await QrLocalService.save(QrLocalModel(
          codigo: _codigoController.text.trim(),
          condominio: widget.condominio,
          casa: widget.casaNumero,
          expira: expiraTs?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
          usosRestantes: usosRestantes,
          propietarioId: ci != null ? 'visitante_$ci' : null,
          propietarioNombre: nombre,
        ));
      } catch (e) {
        // No bloqueamos el flujo si la persistencia local falla
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = constraints.maxWidth < 380 ? 12.0 : 24.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(sidePadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded),
                              Text(
                                'Ingrese el código de la casa',
                                style: TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
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
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: Text(
                              _autoVerificando ? 'Verificando...' : 'Ver QR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
