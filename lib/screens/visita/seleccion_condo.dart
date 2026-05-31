import 'package:flutter/material.dart';
import '../../services/condominio_service.dart';
import 'seleccion_casa_screen.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/back_handler.dart';

class SeleccionCondominioScreen extends StatelessWidget {
  const SeleccionCondominioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Entrada (por código de casa)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<String>>(
          stream: CondominioService.streamCondominios(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 56, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text(
                        'No se pudieron cargar los condominios',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final lista = snapshot.data!;
            if (lista.isEmpty) {
              return const Center(child: Text('No hay condominios registrados'));
            }
            return ListView.builder(
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final nombre = lista[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.home_work_rounded),
                    title: Text('Condominio $nombre'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeleccionCasaScreen(condominioId: nombre),
                        ),
                      );
                    },
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
