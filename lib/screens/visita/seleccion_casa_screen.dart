import 'package:flutter/material.dart';
import '../../services/condominio_service.dart';
import 'ingreso_casa_screen.dart';

class SeleccionCasaScreen extends StatelessWidget {
  final String condominioId;

  const SeleccionCasaScreen({super.key, required this.condominioId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrada - $condominioId')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<int>>( 
          stream: CondominioService.streamCasas(condominioId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final casas = snapshot.data!;
            if (casas.isEmpty) {
              return const Center(child: Text('Sin casas registradas'));
            }
            return ListView.builder(
              itemCount: casas.length,
              itemBuilder: (context, index) {
                final casaNum = casas[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.home_rounded),
                title: Text('Casa $casaNum'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IngresoCasaScreen(
                            casaNumero: casaNum,
                            condominio: condominioId,
                      ),
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
