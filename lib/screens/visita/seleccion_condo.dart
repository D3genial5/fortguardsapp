import 'package:flutter/material.dart';
import '../../services/condominio_service.dart';
import 'seleccion_casa_screen.dart';
import 'package:go_router/go_router.dart';

class SeleccionCondominioScreen extends StatelessWidget {
  const SeleccionCondominioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
