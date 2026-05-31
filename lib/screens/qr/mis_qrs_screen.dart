import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/back_handler.dart';
import '../../services/secure_storage_service.dart';
import '../../services/qr_local_service.dart';
import '../../models/qr_local_model.dart';

class MisQrsScreen extends StatefulWidget {
  const MisQrsScreen({super.key});

  @override
  State<MisQrsScreen> createState() => _MisQrsScreenState();
}

class _MisQrsScreenState extends State<MisQrsScreen> {
  String? _visitanteCi;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarVisitante();
  }

  Future<void> _cargarVisitante() async {
    final ci = await SecureStorageService.getVisitanteCi();
    if (!mounted) return;
    setState(() {
      _visitanteCi = ci;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis QRs'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _visitanteCi == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Primero debes registrarte como visitante',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('access_requests')
                          .where('ci', isEqualTo: _visitanteCi)
                          .where('estado', isEqualTo: 'aceptada')
                          .snapshots(),
                      builder: (context, snapshot) {
                        return FutureBuilder<List<QrLocalModel>>(
                          future: QrLocalService.listAll(),
                          builder: (context, localSnap) {
                            final waiting =
                                snapshot.connectionState == ConnectionState.waiting ||
                                    localSnap.connectionState == ConnectionState.waiting;
                            if (waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final localQrs = localSnap.data ?? const <QrLocalModel>[];
                            final firestoreDocs = snapshot.data?.docs ?? const [];

                            if (localQrs.isEmpty && firestoreDocs.isEmpty) {
                              return ListView(
                                children: const [
                                  SizedBox(height: 100),
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text('No tienes QRs aprobados'),
                                        SizedBox(height: 8),
                                        Text(
                                          'Solicita acceso a una casa o usa un código de casa',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return ListView(
                              children: [
                                ...localQrs.map(_buildLocalCard),
                                ...firestoreDocs.map(_buildFirestoreCard),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // QR local (visita por código de casa)
  // --------------------------------------------------------------------------
  Widget _buildLocalCard(QrLocalModel q) {
    final ahora = DateTime.now();
    final expirado = q.expira.isBefore(ahora);
    final sinUsos = q.usosRestantes <= 0;
    final color = (expirado || sinUsos)
        ? Colors.red
        : (q.expira.difference(ahora).inHours < 6 ? Colors.orange : Colors.green);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/qr-casa', extra: {
            'casa': q.casa.toString(),
            'condominio': q.condominio,
            'codigoQr': q.codigo,
            'usosRestantes': q.usosRestantes,
            'fechaExpiracion': q.expira.toIso8601String(),
            'forzarCodigoCasa': true,
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.home_rounded, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Casa ${q.casa} · ${q.condominio}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expirado
                          ? 'Expirado'
                          : sinUsos
                              ? 'Sin usos'
                              : 'Vence: ${DateFormat('dd/MM HH:mm').format(q.expira)} · ${q.usosRestantes} usos',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código: ${q.codigo}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // QR aprobado via access_request (Firestore)
  // --------------------------------------------------------------------------
  Widget _buildFirestoreCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    final ahora = DateTime.now();

    DateTime? fechaExpiracion;
    final fechaExp = data['fechaExpiracion'];
    if (fechaExp is Timestamp) {
      fechaExpiracion = fechaExp.toDate();
    } else if (fechaExp is String) {
      fechaExpiracion = DateTime.tryParse(fechaExp);
    }

    String tipoAcceso = data['tipoAcceso'] as String? ?? 'usos';
    final usosRestantes = data['usosRestantes'] as int? ?? data['codigoUsos'] as int? ?? 0;
    if (tipoAcceso == 'usos' && usosRestantes >= 999999) {
      tipoAcceso = 'indefinido';
    }

    final estaExpirado = fechaExpiracion != null && fechaExpiracion.isBefore(ahora);
    final sinUsos = tipoAcceso != 'indefinido' && usosRestantes <= 0;

    String duracionTexto;
    Color duracionColor;
    if (estaExpirado) {
      duracionTexto = 'Expirado';
      duracionColor = Colors.red;
    } else if (sinUsos) {
      duracionTexto = 'Sin usos';
      duracionColor = Colors.red;
    } else if (tipoAcceso == 'indefinido') {
      duracionTexto = 'Indefinido';
      duracionColor = Colors.green;
    } else if (fechaExpiracion != null) {
      final diferencia = fechaExpiracion.difference(ahora);
      if (diferencia.inDays > 0) {
        duracionTexto = '${diferencia.inDays}d restantes';
        duracionColor = diferencia.inDays > 3 ? Colors.green : Colors.orange;
      } else if (diferencia.inHours > 0) {
        duracionTexto = '${diferencia.inHours}h restantes';
        duracionColor = Colors.orange;
      } else {
        duracionTexto = '${diferencia.inMinutes}m restantes';
        duracionColor = Colors.red;
      }
    } else {
      duracionTexto = 'Por usos';
      duracionColor = Colors.blue;
    }

    final condominio = data['condominio']?.toString() ?? '';
    final casaNumero = data['casaNumero'] ?? 0;
    final fechaFormateada = fechaExpiracion != null
        ? DateFormat('dd/MM/yyyy – HH:mm').format(fechaExpiracion)
        : 'Sin expiración';
    final codigoQr = data['codigoQr'] as String?;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/qr-casa', extra: {
            'casa': 'Casa $casaNumero',
            'condominio': condominio,
            'docId': docId,
            'tipoAcceso': tipoAcceso,
            'usosRestantes': usosRestantes,
            'codigoQr': codigoQr,
            'fechaExpiracion': fechaExpiracion?.toIso8601String(),
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: duracionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code_2_rounded, color: duracionColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Casa $casaNumero - $condominio',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tipoAcceso == 'indefinido' ? 'Acceso indefinido' : 'Vence: $fechaFormateada',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: duracionColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            duracionTexto,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: duracionColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tipoAcceso == 'indefinido' ? 'Usos: ∞' : 'Usos: $usosRestantes',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
