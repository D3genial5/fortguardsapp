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
import '../../services/migration_service.dart';
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

  bool _esSolicitudQrInvalida(SolicitudModel solicitud) {
    if (solicitud.estado != 'aceptada') return false;

    final tipo = solicitud.tipoAcceso ?? 'usos';
    final sinUsos = tipo != 'indefinido' &&
        solicitud.usosRestantes != null &&
        solicitud.usosRestantes! <= 0;
    final expiradoPorTiempo = tipo == 'tiempo' &&
        solicitud.fechaExpiracion != null &&
        DateTime.now().isAfter(solicitud.fechaExpiracion!);

    return sinUsos || expiradoPorTiempo;
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
        final docId = d.id; // Guardar el ID del documento
        final fechaTs = data['fecha'];
        final fecha = fechaTs is Timestamp ? fechaTs.toDate() : DateTime.now();
        
        // Obtener fecha de expiración si existe
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
        String? tipoAcceso = data['tipoAcceso'] as String?;
        int? usosRestantes = data['usosRestantes'] as int? ?? data['codigoUsos'] as int?;
        
        // Detectar acceso indefinido por usos altos (999999)
        if (tipoAcceso == null && usosRestantes != null && usosRestantes >= 999999) {
          tipoAcceso = 'indefinido';
        }
        
        return SolicitudModel.fromJson({
          ...data,
          'docId': docId,
          'fecha': fecha.toIso8601String(),
          'tipoAcceso': tipoAcceso ?? 'usos',
          'usosRestantes': usosRestantes ?? 1,
          'fechaExpiracion': fechaExpiracion?.toIso8601String(),
          'codigoQr': data['codigoQr'],
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _verQr(SolicitudModel solicitud) {
    context.push('/qr-casa', extra: {
      'casa': 'Casa ${solicitud.casaNumero}',
      'condominio': solicitud.condominio,
      'docId': solicitud.docId, // ID específico de esta solicitud
      'tipoAcceso': solicitud.tipoAcceso,
      'usosRestantes': solicitud.usosRestantes,
      'codigoQr': solicitud.codigoQr,
      'fechaExpiracion': solicitud.fechaExpiracion?.toIso8601String(),
    });
  }

  void _irASolicitar() {
    context.push('/solicitud-acceso');
  }

  Future<void> _ejecutarMigracion() async {
    final messenger = ScaffoldMessenger.of(context);
    
    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migrar datos'),
        content: const Text(
          'Esto actualizará las solicitudes antiguas con los campos faltantes.\n\n'
          '¿Deseas continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Migrar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    // Mostrar loading
    messenger.showSnackBar(
      const SnackBar(content: Text('Migrando datos...')),
    );
    
    // Ejecutar migración
    final resultado = await MigrationService.migrarAccessRequests();
    
    if (!mounted) return;
    
    // Mostrar resultado
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Migración completada:\n'
          '• Total: ${resultado['total']}\n'
          '• Migrados: ${resultado['migrados']}\n'
          '• Ya actualizados: ${resultado['yaActualizados']}\n'
          '• Errores: ${resultado['errores']}'
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: resultado['errores'] == 0 ? Colors.green : Colors.orange,
      ),
    );
    
    // Recargar datos
    _cargarDatosVisitante();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Migrar datos antiguos',
            onPressed: _ejecutarMigracion,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Visitante: $_nombre\nCI: $_ci',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _solicitudes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_late_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No tienes solicitudes registradas',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solicita un acceso para generar tu QR de ingreso.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _solicitudes.length,
                      itemBuilder: (context, index) {
                        final s = _solicitudes[index];
                        final fecha = DateFormat('dd/MM/yyyy – HH:mm').format(s.fecha);
                        final qrInvalido = _esSolicitudQrInvalida(s);
                        
                        // Usar la descripción real del tipo de acceso
                        final duracion = qrInvalido ? 'QR inválido' : s.descripcionAcceso;
                        
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text('Estado: ${s.estado}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('Fecha: $fecha', maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (s.estado == 'aceptada')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: qrInvalido
                                            ? Colors.red.withValues(alpha: 0.12)
                                            : s.tipoAcceso == 'indefinido' 
                                                ? Colors.purple.withValues(alpha: 0.15)
                                                : Colors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        duracion,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: qrInvalido
                                              ? Colors.red
                                              : s.tipoAcceso == 'indefinido' 
                                                  ? Colors.purple 
                                                  : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (s.estado == 'aceptada')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final usarColumna = constraints.maxWidth < 360;

                                        final botonVerQr = FilledButton.icon(
                                          icon: const Icon(Icons.qr_code),
                                          onPressed: (_isLoading || qrInvalido) ? null : () => _verQr(s),
                                          label: const Text(
                                            'Ver QR',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          ),
                                        );

                                        final botonDescargar = FilledButton.icon(
                                          icon: _isLoading
                                              ? SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.download),
                                          onPressed: (_isLoading || qrInvalido) ? null : () => _descargarQr(s),
                                          label: Text(
                                            _isLoading ? 'Guardando' : 'Descargar',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          ),
                                        );

                                        if (usarColumna) {
                                          return Column(
                                            children: [
                                              SizedBox(width: double.infinity, child: botonVerQr),
                                              const SizedBox(height: 8),
                                              SizedBox(width: double.infinity, child: botonDescargar),
                                            ],
                                          );
                                        }

                                        return Row(
                                          children: [
                                            Expanded(child: botonVerQr),
                                            const SizedBox(width: 8),
                                            Expanded(child: botonDescargar),
                                          ],
                                        );
                                      },
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4200),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _irASolicitar,
                icon: const Icon(Icons.add),
                label: const Text('Solicitar acceso'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
