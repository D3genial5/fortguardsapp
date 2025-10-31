import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/qr_local_model.dart';
import '../../models/propietario_model.dart';
import '../../services/qr_local_service.dart';

class QrCasaScreen extends StatelessWidget {
  final String casa;
  final String condominio;

  const QrCasaScreen({
    super.key,
    required this.casa,
    required this.condominio,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = 'CONDO:$condominio|CASA:$casa';

    return Scaffold(
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
        child: LayoutBuilder(
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
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Casa: $casa',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Condominio: $condominio',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final codigo = qrData; // usamos el mismo payload del QR
                            final casaNumMatch = RegExp(r'Casa (\d+)').firstMatch(casa);
                            final casaNumero = casaNumMatch != null ? int.parse(casaNumMatch.group(1)!) : 0;

                            // Obtener usuario actual (propietario o visitante)
                            final prefs = await SharedPreferences.getInstance();
                            String? userId;
                            String? userName;
                            
                            // Verificar si es propietario
                            final propietarioJson = prefs.getString('propietario');
                            if (propietarioJson != null) {
                              final propietario = PropietarioModel.fromJson(jsonDecode(propietarioJson));
                              userId = '${propietario.condominio}_${propietario.casa.numero}';
                              userName = propietario.personas.isNotEmpty ? propietario.personas.first : 'Propietario';
                            } else {
                              // Verificar si es visitante
                              final visitanteNombre = prefs.getString('visitante_nombre');
                              final visitanteCi = prefs.getString('visitante_ci');
                              if (visitanteNombre != null && visitanteCi != null) {
                                userId = 'visitante_$visitanteCi';
                                userName = visitanteNombre;
                              }
                            }

                            final qrModel = QrLocalModel(
                              codigo: codigo,
                              condominio: condominio,
                              casa: casaNumero,
                              expira: DateTime.now().add(const Duration(hours: 12)),
                              usosRestantes: 1,
                              propietarioId: userId,
                              propietarioNombre: userName,
                            );
                            await QrLocalService.save(qrModel);
                            if (!context.mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('QR guardado localmente')));
                            context.push('/mis-qrs');
                          } catch (e) {
                            messenger.showSnackBar(const SnackBar(content: Text('Error al guardar QR')));
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar QR'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
