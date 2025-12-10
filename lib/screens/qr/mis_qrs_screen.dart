import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/back_handler.dart';

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitanteCi = prefs.getString('visitante_ci');
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {});
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                                    'Solicita acceso a una casa y espera la aprobación',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      
                      final qrs = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: qrs.length,
                        itemBuilder: (context, index) {
                          final data = qrs[index].data() as Map<String, dynamic>;
                          final ahora = DateTime.now();
                          
                          // Obtener fecha de expiración
                          DateTime? fechaExpiracion;
                          final fechaExp = data['fechaExpiracion'];
                          if (fechaExp != null) {
                            if (fechaExp is Timestamp) {
                              fechaExpiracion = fechaExp.toDate();
                            } else if (fechaExp is String) {
                              fechaExpiracion = DateTime.tryParse(fechaExp);
                            }
                          }
                          
                          // Obtener tipo de acceso y usos
                          String tipoAcceso = data['tipoAcceso'] as String? ?? 'usos';
                          final usosRestantes = data['usosRestantes'] as int? ?? data['codigoUsos'] as int? ?? 0;
                          
                          // Detectar acceso indefinido por usos altos (999999)
                          if (tipoAcceso == 'usos' && usosRestantes >= 999999) {
                            tipoAcceso = 'indefinido';
                          }
                          
                          final estaExpirado = fechaExpiracion != null && fechaExpiracion.isBefore(ahora);
                          final sinUsos = tipoAcceso != 'indefinido' && usosRestantes <= 0;
                          
                          // Calcular texto de duración
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
                          
                          final condominio = data['condominio'] ?? '';
                          final casaNumero = data['casaNumero'] ?? 0;
                          final fechaFormateada = fechaExpiracion != null 
                              ? DateFormat('dd/MM/yyyy – HH:mm').format(fechaExpiracion)
                              : 'Sin expiración';
                          
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
                                            'Casa $casaNumero - $condominio',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tipoAcceso == 'indefinido' 
                                                ? 'Acceso indefinido'
                                                : 'Vence: $fechaFormateada',
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
                                                  tipoAcceso == 'indefinido' 
                                                      ? 'Usos: ∞'
                                                      : 'Usos: $usosRestantes',
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
