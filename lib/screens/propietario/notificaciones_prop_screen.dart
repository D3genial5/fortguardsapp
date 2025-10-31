import 'package:flutter/material.dart';

import '../../models/notificacion_model.dart';
import '../../services/notificacion_service.dart';
import '../../models/propietario_model.dart';

class NotificacionesPropScreen extends StatelessWidget {
  final int initialIndex; // 0 = privadas, 1 = condominio
  final PropietarioModel propietario;
  
  const NotificacionesPropScreen({
    super.key,
    required this.propietario,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex, // usa el índice indicado
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Privadas'),
              Tab(text: 'Condominio'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStream(privada: true),
            _buildStream(privada: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStream({required bool privada}) {
    final stream = privada
        ? NotificacionService.streamNotificaciones(
            condominioId: propietario.condominio,
            casaNumero: propietario.casa.numero,
          )
        : NotificacionService.streamNotificacionesCondominio(
            condominioId: propietario.condominio,
          );

    return StreamBuilder<List<NotificacionModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notis = snapshot.data!;
        if (notis.isEmpty) {
          return const Center(child: Text('Sin notificaciones'));
        }
        return ListView.builder(
          itemCount: notis.length,
          itemBuilder: (context, index) {
            final n = notis[index];
            return ListTile(
              leading: Icon(privada ? Icons.mail : Icons.campaign,
                  color: privada ? Colors.teal : Colors.blue),
              title: Text(n.titulo),
              subtitle: Text(n.mensaje),
              trailing: n.visto ? null : const Icon(Icons.fiber_new, color: Colors.red),
              onTap: () async {
                await NotificacionService.marcarVisto(n.id);
              },
            );
          },
        );
      },
    );
  }
}
