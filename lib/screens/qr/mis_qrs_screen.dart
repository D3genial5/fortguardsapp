import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../widgets/back_handler.dart';

import '../../models/qr_local_model.dart';
import '../../services/qr_local_service.dart';

class MisQrsScreen extends StatefulWidget {
  const MisQrsScreen({super.key});

  @override
  State<MisQrsScreen> createState() => _MisQrsScreenState();
}

class _MisQrsScreenState extends State<MisQrsScreen> {
  late Future<List<QrLocalModel>> _futureQrs;

  @override
  void initState() {
    super.initState();
    _futureQrs = QrLocalService.listAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureQrs = QrLocalService.listAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text("Mis QRs"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<QrLocalModel>>(
          future: _futureQrs,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final qrs = snapshot.data!;
            if (qrs.isEmpty) {
              return const Center(child: Text('No tienes QRs descargados'));
            }
            return ListView.builder(
              itemCount: qrs.length,
              itemBuilder: (context, index) {
                final qr = qrs[index];
                final ahora = DateTime.now();
                final estaExpirado = qr.expira.isBefore(ahora);
                final sinUsos = qr.usosRestantes <= 0;
                final fechaFormateada = DateFormat('dd/MM/yyyy – HH:mm').format(qr.expira);
                
                // Calcular tiempo restante
                String duracionTexto;
                Color duracionColor;
                if (estaExpirado || sinUsos) {
                  duracionTexto = estaExpirado ? 'Expirado' : 'Sin usos';
                  duracionColor = Colors.red;
                } else {
                  final diferencia = qr.expira.difference(ahora);
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
                }
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.push('/qr-casa', extra: {
                        'casa': 'Casa ${qr.casa}',
                        'condominio': qr.condominio,
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: duracionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              color: duracionColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Casa ${qr.casa} - ${qr.condominio}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vence: $fechaFormateada',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: duracionColor.withOpacity(0.15),
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
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Usos: ${qr.usosRestantes}',
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
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      ),
    );
  }
}
