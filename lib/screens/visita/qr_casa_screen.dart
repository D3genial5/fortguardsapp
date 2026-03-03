import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/back_handler.dart';

class QrCasaScreen extends StatefulWidget {
  final String casa;
  final String condominio;
  // Datos opcionales pasados directamente (para evitar búsqueda en Firestore)
  final String? docId;
  final String? tipoAcceso;
  final int? usosRestantes;
  final String? codigoQr;
  final String? fechaExpiracion;
  final bool esSalida;
  final bool forzarCodigoCasa;

  const QrCasaScreen({
    super.key,
    required this.casa,
    required this.condominio,
    this.docId,
    this.tipoAcceso,
    this.usosRestantes,
    this.codigoQr,
    this.fechaExpiracion,
    this.esSalida = false,
    this.forzarCodigoCasa = false,
  });

  @override
  State<QrCasaScreen> createState() => _QrCasaScreenState();
}

class _QrCasaScreenState extends State<QrCasaScreen> {
  String? _codigoQr;
  String? _tipoAcceso;
  int? _usosRestantes;
  DateTime? _fechaExpiracion;
  String? _sessionId;
  String? _visitanteNombre;
  String? _visitanteCi;
  bool _visitanteLoaded = false;
  bool _isLoading = true;
  bool _estadoReseteado = false;
  bool _entradaConfirmada = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ingresoSubscription;
  String? _error;

  void _volver() {
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
    context.go('/acceso-general');
  }

  @override
  void initState() {
    super.initState();
    _ensureSessionId();
    _cargarVisitanteLocal();
    _cargarCodigoQr();
  }

  @override
  void dispose() {
    _ingresoSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ensureSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    var sessionId = prefs.getString('session_id');
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = '${widget.condominio}_${widget.casa}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('session_id', sessionId);
    }
    if (!mounted) return;
    setState(() {
      _sessionId = sessionId;
    });
    _iniciarEscuchaEntradaConfirmada(sessionId);
  }

  void _iniciarEscuchaEntradaConfirmada(String sessionId) {
    if (widget.esSalida || !widget.forzarCodigoCasa || sessionId.isEmpty) {
      return;
    }

    _ingresoSubscription?.cancel();
    _ingresoSubscription = FirebaseFirestore.instance
        .collection('registros_ingreso')
        .where('sessionId', isEqualTo: sessionId)
        .where('estado', isEqualTo: 'ingresado')
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (_entradaConfirmada || snapshot.docs.isEmpty) return;
      _entradaConfirmada = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ingreso_activo', true);
      await prefs.setBool('qr_pendiente', false);

      if (!mounted) return;
      context.go('/seleccion-accion');
    });
  }

  Future<void> _cargarVisitanteLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('visitante_nombre');
    final ci = prefs.getString('visitante_ci');
    if (!mounted) return;
    setState(() {
      _visitanteNombre = nombre;
      _visitanteCi = ci;
      _visitanteLoaded = true;
    });
  }

  Future<void> _cargarCodigoQr() async {
    try {
      // Si se pasaron datos directamente, usarlos sin consultar Firestore
      if (widget.docId != null || widget.codigoQr != null) {
        String? tipoAcceso = widget.tipoAcceso;
        int? usosRestantes = widget.usosRestantes;
        DateTime? fechaExpiracion;
        
        // Detectar acceso indefinido por usos altos
        if (tipoAcceso == null && usosRestantes != null && usosRestantes >= 999999) {
          tipoAcceso = 'indefinido';
        }
        
        setState(() {
          _codigoQr = widget.codigoQr;
          _tipoAcceso = tipoAcceso;
          _usosRestantes = usosRestantes;
          if (widget.fechaExpiracion != null) {
            fechaExpiracion = DateTime.tryParse(widget.fechaExpiracion!);
            _fechaExpiracion = fechaExpiracion;
          }
          _isLoading = false;
        });

        if (_debeInvalidarQrActual(
          tipoAcceso: tipoAcceso,
          usosRestantes: usosRestantes,
          fechaExpiracion: fechaExpiracion,
        )) {
          await _resetEstadoVisitaLocal();
        }
        return;
      }
      
      // Fallback: buscar en Firestore si no se pasaron datos
      final prefs = await SharedPreferences.getInstance();
      final ci = prefs.getString('visitante_ci');
      
      // Buscar la solicitud aprobada para este visitante, condominio y casa
      final casaNumMatch = RegExp(r'(\d+)').firstMatch(widget.casa);
      final casaNumero = casaNumMatch != null ? int.parse(casaNumMatch.group(1)!) : 0;

      // Si tenemos CI, intentamos buscar solicitud aprobada
      // excepto cuando se forzó el flujo por código de casa.
      if (!widget.forzarCodigoCasa && ci != null) {
        final query = await FirebaseFirestore.instance
            .collection('access_requests')
            .where('ci', isEqualTo: ci)
            .where('condominio', isEqualTo: widget.condominio)
            .where('casaNumero', isEqualTo: casaNumero)
            .where('estado', isEqualTo: 'aceptada')
            .get();

        if (query.docs.isNotEmpty) {
          // Ordenar por fecha de aprobación (más reciente primero)
          final docs = query.docs.toList();
          docs.sort((a, b) {
            final fechaA = a.data()['fechaAprobacion'];
            final fechaB = b.data()['fechaAprobacion'];
            if (fechaA == null && fechaB == null) return 0;
            if (fechaA == null) return 1;
            if (fechaB == null) return -1;
            if (fechaA is Timestamp && fechaB is Timestamp) {
              return fechaB.compareTo(fechaA);
            }
            return 0;
          });
          
          // Usar la solicitud más reciente
          final data = docs.first.data();
          
          // Obtener tipo de acceso (con fallback inteligente)
          String? tipoAcceso = data['tipoAcceso'] as String?;
          int? usosRestantes = data['usosRestantes'] as int?;
          
          // Si usosRestantes es muy alto (999999), probablemente es indefinido
          if (tipoAcceso == null && usosRestantes != null && usosRestantes >= 999999) {
            tipoAcceso = 'indefinido';
          }
          
          setState(() {
            _codigoQr = data['codigoQr'] as String?;
            _tipoAcceso = tipoAcceso;
            _usosRestantes = usosRestantes;
            
            final fechaExp = data['fechaExpiracion'];
            if (fechaExp != null) {
              if (fechaExp is Timestamp) {
                _fechaExpiracion = fechaExp.toDate();
              } else if (fechaExp is String) {
                _fechaExpiracion = DateTime.tryParse(fechaExp);
              }
            }
            
            _isLoading = false;
          });

          if (_debeInvalidarQrActual(
            tipoAcceso: tipoAcceso,
            usosRestantes: usosRestantes,
            fechaExpiracion: _fechaExpiracion,
          )) {
            await _resetEstadoVisitaLocal();
          }
          return;
        }
      }
      
      // Sin solicitud aprobada - usar formato legacy (acceso por código de casa)
      // Este es el flujo cuando el propietario le da el código directamente
      // IMPORTANTE: Consultar Firestore para obtener los usos reales del código de casa
      try {
        final casaDoc = await FirebaseFirestore.instance
            .collection('condominios')
            .doc(widget.condominio)
            .collection('casas')
            .doc(casaNumero.toString())
            .get();
        
        // Obtener los usos del código de casa desde Firestore
        final codigoUsos = casaDoc.exists ? (casaDoc.data()?['codigoUsos'] as int?) : null;
        
        setState(() {
          _codigoQr = null; // Usará el formato CONDO:xxx|CASA:xxx
          _tipoAcceso = 'codigo_casa';
          _usosRestantes = codigoUsos; // Mostrar los usos reales del código
          _isLoading = false;
        });

        if (_debeInvalidarQrActual(
          tipoAcceso: 'codigo_casa',
          usosRestantes: codigoUsos,
          fechaExpiracion: null,
        )) {
          await _resetEstadoVisitaLocal();
        }
      } catch (e) {
        // Fallback si hay error al consultar Firestore
        setState(() {
          _codigoQr = null;
          _tipoAcceso = 'codigo_casa';
          _usosRestantes = null;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el QR: $e';
        _isLoading = false;
      });
    }
  }

  bool _esQrInvalido({
    required String? tipoAcceso,
    required int? usosRestantes,
    required DateTime? fechaExpiracion,
  }) {
    final tipo = tipoAcceso ?? 'usos';
    final sinUsos = tipo != 'indefinido' && usosRestantes != null && usosRestantes <= 0;
    final expiradoPorTiempo =
        tipo == 'tiempo' && fechaExpiracion != null && DateTime.now().isAfter(fechaExpiracion);
    return sinUsos || expiradoPorTiempo;
  }

  bool get _qrInvalido => _esQrInvalido(
        tipoAcceso: _tipoAcceso,
        usosRestantes: _usosRestantes,
        fechaExpiracion: _fechaExpiracion,
      );

  bool _debeInvalidarQrActual({
    required String? tipoAcceso,
    required int? usosRestantes,
    required DateTime? fechaExpiracion,
  }) {
    if (widget.esSalida) return false;
    return _esQrInvalido(
      tipoAcceso: tipoAcceso,
      usosRestantes: usosRestantes,
      fechaExpiracion: fechaExpiracion,
    );
  }

  Future<void> _resetEstadoVisitaLocal() async {
    if (_estadoReseteado) return;
    _estadoReseteado = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('qr_pendiente', false);
    await prefs.setBool('ingreso_activo', false);
    await prefs.remove('session_id');
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora);
    
    if (diferencia.isNegative) {
      return 'Expirado';
    } else if (diferencia.inDays > 0) {
      return '${diferencia.inDays}d ${diferencia.inHours % 24}h';
    } else if (diferencia.inHours > 0) {
      return '${diferencia.inHours}h ${diferencia.inMinutes % 60}m';
    } else {
      return '${diferencia.inMinutes}m';
    }
  }

  String _buildQrDataWithSession({required bool esEntrada}) {
    final sessionId = _sessionId ??
        '${widget.condominio}_${widget.casa}_${DateTime.now().millisecondsSinceEpoch}';

    // Formato: TIPO|SESSION|CONDO|CASA
    final tipo = esEntrada ? 'ENTRADA' : 'SALIDA';
    var qrData = '$tipo|SESSION:$sessionId|CONDO:${widget.condominio}|CASA:${widget.casa}';
    if (widget.forzarCodigoCasa) {
      qrData += '|ORIGEN:CASA';
    }
    if (_visitanteCi != null && _visitanteCi!.isNotEmpty) {
      qrData += '|CI:${_visitanteCi!}';
    }
    if (_visitanteNombre != null && _visitanteNombre!.isNotEmpty) {
      final nombreEncoded = Uri.encodeComponent(_visitanteNombre!);
      qrData += '|NOMBRE:$nombreEncoded';
    }
    return qrData;
  }

  Widget _buildQrCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String qrData,
    required double qrSize,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 3),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: qrSize,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: color,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Instrucción
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title.contains('ENTRADA')
                    ? 'Muestra este QR al guardia para ENTRAR'
                    : 'Muestra este QR al guardia para SALIR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrInvalidoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.block_rounded, color: Colors.red[700], size: 44),
            const SizedBox(height: 10),
            const Text(
              'QR inválido',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Este QR ya no se puede usar. Solicita un nuevo acceso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esSalida = widget.esSalida;
    final qrTitle = esSalida ? 'QR DE SALIDA' : 'QR DE ENTRADA';
    final qrIcon = esSalida ? Icons.logout_rounded : Icons.login_rounded;
    final qrColor = esSalida ? Colors.orange : Colors.green;
    final qrData = _buildQrDataWithSession(esEntrada: !esSalida);
    final qrInvalido = !esSalida && _qrInvalido;

    return BackHandler(
      onBackPressed: _volver,
      child: Scaffold(
        appBar: AppBar(
          title: Text(esSalida ? 'QR de Salida' : 'QR de Entrada'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _volver,
          ),
        ),
        body: SafeArea(
        child: _isLoading || _sessionId == null || !_visitanteLoaded
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => context.go('/seleccion-accion'),
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                ),
              )
            : (_visitanteNombre == null || _visitanteCi == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Completa tu registro de visitante para generar el QR.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.go('/registro-visita'),
                          child: const Text('Ir a Registro'),
                        ),
                      ],
                    ),
                  ),
                )
            : LayoutBuilder(
          builder: (context, constraints) {
            final maxQrSize = (constraints.maxWidth - 100).clamp(150.0, 200.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // QR seleccionado (Entrada o Salida)
                      qrInvalido
                          ? _buildQrInvalidoCard()
                          : _buildQrCard(
                              context: context,
                              title: qrTitle,
                              icon: qrIcon,
                              color: qrColor,
                              qrData: qrData,
                              qrSize: maxQrSize,
                            ),
                      const SizedBox(height: 16),
                      Text(
                        'Casa: ${widget.casa}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Condominio: ${widget.condominio}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_codigoQr != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Código: $_codigoQr',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Información del QR',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Icon(Icons.schedule, color: Colors.blue[700]),
                                    const SizedBox(height: 4),
                                    Text(
                                      _tipoAcceso == 'tiempo' ? 'Expira' : 'Tipo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _tipoAcceso == 'tiempo' && _fechaExpiracion != null
                                          ? _formatearFecha(_fechaExpiracion!)
                                          : _tipoAcceso == 'indefinido' 
                                              ? 'Indefinido'
                                              : 'Por usos',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.grey[300],
                                ),
                                Column(
                                  children: [
                                    Icon(Icons.repeat, color: Colors.blue[700]),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Usos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _tipoAcceso == 'indefinido'
                                          ? '∞'
                                          : '${_usosRestantes ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Mensaje informativo
                    ],
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
