import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../widgets/back_handler.dart';

import '../../models/solicitud_model.dart';
import '../../models/qr_local_model.dart';
import '../../models/propietario_model.dart';
import '../../services/qr_local_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MiQrScreen extends StatefulWidget {
  const MiQrScreen({super.key});

  @override
  State<MiQrScreen> createState() => _MiQrScreenState();
}

class _MiQrScreenState extends State<MiQrScreen> {
  String? _nombre;
  String? _ci;
  List<SolicitudModel> _solicitudes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosVisitante();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se ejecuta cada vez que esta pantalla vuelve a ser visible
    _cargarDatosVisitante();
  }

  Future<void> _cargarDatosVisitante() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final nombre = prefs.getString('visitante_nombre');
      final ci = prefs.getString('visitante_ci');

      if (nombre == null || ci == null) {
        if (!mounted) return;
        setState(() {
          _ci = null;
        });
        return;
      }

      // Consultar solicitudes del visitante
      final query = await FirebaseFirestore.instance
          .collection('access_requests')
          .where('ci', isEqualTo: ci)
          .get();

      final solicitudes = query.docs.map((d) {
        final data = d.data();
        final fechaTs = data['fecha'];
        final fecha = fechaTs is Timestamp ? fechaTs.toDate() : DateTime.now();
        return SolicitudModel.fromJson({
          ...data,
          'fecha': fecha.toIso8601String(),
        });
      }).toList();

      if (!mounted) return;
      setState(() {
        _nombre = nombre;
        _ci = ci;
        _solicitudes = solicitudes;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Error al cargar solicitudes')),
      );
    }
  }

  Future<void> _descargarQr(SolicitudModel solicitud) async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final casaDoc = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(solicitud.condominio)
          .collection('casas')
          .doc(solicitud.casaNumero.toString())
          .get();

      final codigo = casaDoc.data()?['codigoCasa']?.toString() ?? '';
      final expiraTs = casaDoc.data()?['codigoExpira'];
      final expira = expiraTs is Timestamp ? expiraTs.toDate() : DateTime.now().add(const Duration(hours: 12));
      final usos = casaDoc.data()?['codigoUsos'] ?? 1;

      // Para visitantes, usar información del visitante en lugar del propietario
      String? visitanteId;
      String? visitanteNombre;
      
      // Intentar obtener propietario actual (si está logueado)
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('propietario');
        if (jsonString != null) {
          final jsonMap = jsonDecode(jsonString);
          final propietarioActual = PropietarioModel.fromJson(jsonMap);
          visitanteId = '${propietarioActual.condominio}_${propietarioActual.casa.numero}';
          visitanteNombre = propietarioActual.personas.isNotEmpty ? propietarioActual.personas.first : null;
        } else {
          // Si no hay propietario, usar datos del visitante
          visitanteId = 'visitante_${solicitud.ci}';
          visitanteNombre = solicitud.nombre;
        }
      } catch (e) {
        // Fallback: usar datos del visitante
        visitanteId = 'visitante_${solicitud.ci}';
        visitanteNombre = solicitud.nombre;
      }

      final qr = QrLocalModel(
        codigo: codigo,
        condominio: solicitud.condominio,
        casa: solicitud.casaNumero,
        expira: expira,
        usosRestantes: usos,
        propietarioId: visitanteId,
        propietarioNombre: visitanteNombre,
      );
      
      // Guardar el QR localmente
      await QrLocalService.save(qr);
      
      if (!mounted) return;
      
      // Mostrar mensaje de éxito pero permanecer en esta pantalla
      messenger.showSnackBar(
        const SnackBar(
          content: Text('QR guardado localmente en la sección "Mis QRs"'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Error al guardar el QR localmente'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _verQr(SolicitudModel solicitud) {
    context.push('/qr-casa', extra: {
      'casa': 'Casa ${solicitud.casaNumero}',
      'condominio': solicitud.condominio,
    });
  }

  void _irASolicitar() {
    context.push('/solicitud-acceso');
  }

  @override
  Widget build(BuildContext context) {
    if (_ci == null) {
      return BackHandler(
        child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Debes registrar tu información primero'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _irASolicitar,
                icon: const Icon(Icons.edit),
                label: const Text('Registrar información'),
              ),
            ],
          ),
        ),
        ),
      );
    }

    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Mis accesos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/acceso-general');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Visitante: $_nombre\nCI: $_ci', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Expanded(
              child: _solicitudes.isEmpty
                  ? const Center(child: Text('No tienes solicitudes registradas'))
                  : ListView.builder(
                      itemCount: _solicitudes.length,
                      itemBuilder: (context, index) {
                        final s = _solicitudes[index];
                        final fecha = DateFormat('dd/MM/yyyy – HH:mm').format(s.fecha);
                        
                        // Calcular duración estimada del QR (12 horas desde ahora)
                        final expiraEstimado = DateTime.now().add(const Duration(hours: 12));
                        final diferencia = expiraEstimado.difference(DateTime.now());
                        final duracion = '${diferencia.inHours}h de duración';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.condominio} - Casa ${s.casaNumero}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text('Estado: ${s.estado}'),
                                Text('Fecha: $fecha'),
                                if (s.estado == 'aceptada')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Duración del QR: $duracion',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (s.estado == 'aceptada')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            icon: const Icon(Icons.qr_code),
                                            onPressed: _isLoading ? null : () => _verQr(s),
                                            label: const Text('Ver QR'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.icon(
                                            icon: _isLoading ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2),
                                            ) : const Icon(Icons.download),
                                            onPressed: _isLoading ? null : () => _descargarQr(s),
                                            label: Text(_isLoading ? 'Guardando' : 'Descargar'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _irASolicitar,
              icon: const Icon(Icons.add),
              label: const Text('Solicitar acceso'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
