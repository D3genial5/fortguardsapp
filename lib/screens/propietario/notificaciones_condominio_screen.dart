import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/propietario_model.dart';

class NotificacionesCondominioScreen extends StatefulWidget {
  final PropietarioModel propietario;

  const NotificacionesCondominioScreen({
    super.key,
    required this.propietario,
  });

  @override
  State<NotificacionesCondominioScreen> createState() => _NotificacionesCondominioScreenState();
}

class _NotificacionesCondominioScreenState extends State<NotificacionesCondominioScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones del Condominio'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('condominios')
            .doc(widget.propietario.condominio)
            .collection('notificaciones')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notificaciones = snapshot.data?.docs ?? [];

          if (notificaciones.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notificaciones.length,
            itemBuilder: (context, index) {
              final notificacion = notificaciones[index].data() as Map<String, dynamic>;
              final titulo = notificacion['titulo'] as String? ?? 'Sin título';
              final mensaje = notificacion['mensaje'] as String? ?? 'Sin mensaje';
              final fecha = (notificacion['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
              final importancia = notificacion['importancia'] as String? ?? 'normal';
              
              Color colorImportancia;
              switch (importancia) {
                case 'alta':
                  colorImportancia = Colors.red;
                  break;
                case 'media':
                  colorImportancia = Colors.orange;
                  break;
                default:
                  colorImportancia = Colors.blue;
              }
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorImportancia, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(mensaje),
                      const SizedBox(height: 8),
                      Text(
                        '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorImportancia.withAlpha(50),
                    child: Icon(Icons.notifications, color: colorImportancia),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
