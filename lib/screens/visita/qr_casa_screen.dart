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

  const QrCasaScreen({
    super.key,
    required this.casa,
    required this.condominio,
    this.docId,
    this.tipoAcceso,
    this.usosRestantes,
    this.codigoQr,
    this.fechaExpiracion,
  });

  @override
  State<QrCasaScreen> createState() => _QrCasaScreenState();
}

class _QrCasaScreenState extends State<QrCasaScreen> {
  String? _codigoQr;
  String? _tipoAcceso;
  int? _usosRestantes;
  DateTime? _fechaExpiracion;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCodigoQr();
  }

  Future<void> _cargarCodigoQr() async {
    try {
      // Si se pasaron datos directamente, usarlos sin consultar Firestore
      if (widget.docId != null || widget.codigoQr != null) {
        String? tipoAcceso = widget.tipoAcceso;
        int? usosRestantes = widget.usosRestantes;
        
        // Detectar acceso indefinido por usos altos
        if (tipoAcceso == null && usosRestantes != null && usosRestantes >= 999999) {
          tipoAcceso = 'indefinido';
        }
        
        setState(() {
          _codigoQr = widget.codigoQr;
          _tipoAcceso = tipoAcceso;
          _usosRestantes = usosRestantes;
          if (widget.fechaExpiracion != null) {
            _fechaExpiracion = DateTime.tryParse(widget.fechaExpiracion!);
          }
          _isLoading = false;
        });
        return;
      }
      
      // Fallback: buscar en Firestore si no se pasaron datos
      final prefs = await SharedPreferences.getInstance();
      final ci = prefs.getString('visitante_ci');
      
      // Buscar la solicitud aprobada para este visitante, condominio y casa
      final casaNumMatch = RegExp(r'(\d+)').firstMatch(widget.casa);
      final casaNumero = casaNumMatch != null ? int.parse(casaNumMatch.group(1)!) : 0;

      // Si tenemos CI, intentamos buscar solicitud aprobada
      if (ci != null) {
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
          return;
        }
      }
      
      // Sin solicitud aprobada - usar formato legacy (acceso por código de casa)
      // Este es el flujo cuando el propietario le da el código directamente
      setState(() {
        _codigoQr = null; // Usará el formato CONDO:xxx|CASA:xxx
        _tipoAcceso = 'codigo_casa';
        _usosRestantes = null;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el QR: $e';
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    // El QR contiene el código único o fallback al formato viejo
    final qrData = _codigoQr ?? 'CONDO:${widget.condominio}|CASA:${widget.casa}';

    return BackHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR de la casa'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.pop();
            },
          ),
        ),
        body: SafeArea(
        child: _isLoading 
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
                        onPressed: () => context.pop(),
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
          builder: (context, constraints) {
            final maxQrSize = (constraints.maxWidth - 64).clamp(200.0, 320.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: maxQrSize,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        ),
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
                                              : _tipoAcceso == 'codigo_casa'
                                                  ? 'Código casa'
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
                                      _tipoAcceso == 'indefinido' || _tipoAcceso == 'codigo_casa'
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Muestra este QR al guardia',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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
