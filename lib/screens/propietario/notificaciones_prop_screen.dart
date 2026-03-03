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

  String _formatearFechaHora(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio • $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: const Color(0xFF6E6E73),
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Privadas'),
              Tab(text: 'Condominio'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStream(context, privada: true),
            _buildStream(context, privada: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStream(BuildContext context, {required bool privada}) {
    final stream = privada
        ? NotificacionService.streamNotificaciones(
            condominioId: propietario.condominio,
            casaNumero: propietario.casa.numero,
          )
        : NotificacionService.streamNotificacionesCondominio(
            condominioId: propietario.condominio,
          );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  privada ? Icons.mail_outline : Icons.campaign_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  privada ? 'Sin notificaciones privadas' : 'Sin notificaciones del condominio',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notis.length,
          itemBuilder: (context, index) {
            final n = notis[index];
            return _buildNotificacionCard(context, n, privada, cardColor, isDark);
          },
        );
      },
    );
  }

  Widget _buildNotificacionCard(BuildContext context, NotificacionModel n, bool privada, Color cardColor, bool isDark) {
    // Obtener info de prioridad (solo para notificaciones de condominio)
    final prioridad = n.prioridad?.toLowerCase() ?? 'media';
    
    Color prioridadColor;
    IconData prioridadIcon;
    String prioridadTexto;
    
    switch (prioridad) {
      case 'urgente':
        prioridadColor = Colors.red;
        prioridadIcon = Icons.warning_rounded;
        prioridadTexto = 'URGENTE';
        break;
      case 'alta':
        prioridadColor = Colors.orange;
        prioridadIcon = Icons.priority_high_rounded;
        prioridadTexto = 'ALTA';
        break;
      case 'baja':
        prioridadColor = Colors.grey;
        prioridadIcon = Icons.arrow_downward_rounded;
        prioridadTexto = 'BAJA';
        break;
      default: // media
        prioridadColor = Colors.blue;
        prioridadIcon = Icons.info_rounded;
        prioridadTexto = 'MEDIA';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: !privada && (prioridad == 'urgente' || prioridad == 'alta')
            ? Border.all(color: prioridadColor.withValues(alpha: 0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await NotificacionService.marcarVisto(n.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (privada ? Theme.of(context).colorScheme.primary : prioridadColor).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      privada ? Icons.mail_rounded : Icons.campaign_rounded,
                      color: privada ? Theme.of(context).colorScheme.primary : prioridadColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (!privada) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: prioridadColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(prioridadIcon, size: 12, color: prioridadColor),
                                const SizedBox(width: 4),
                                Text(
                                  prioridadTexto,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: prioridadColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!n.visto)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                n.mensaje,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatearFechaHora(n.fecha),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
