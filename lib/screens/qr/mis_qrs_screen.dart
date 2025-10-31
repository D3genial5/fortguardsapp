import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/qr_local_model.dart';
import '../../services/qr_local_service.dart';

class MisQrsScreen extends StatefulWidget {
  const MisQrsScreen({super.key});

  @override
  State<MisQrsScreen> createState() => _MisQrsScreenState();
}

class _MisQrsScreenState extends State<MisQrsScreen> {
  late Future<List<QrLocalModel>> _futureQrs;

  @override
  void initState() {
    super.initState();
    _futureQrs = QrLocalService.listAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureQrs = QrLocalService.listAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis QRs"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<QrLocalModel>>(
          future: _futureQrs,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final qrs = snapshot.data!;
            if (qrs.isEmpty) {
              return const Center(child: Text('No tienes QRs descargados'));
            }
            return ListView.builder(
              itemCount: qrs.length,
              itemBuilder: (context, index) {
                final qr = qrs[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: Text('Casa ${qr.casa} - ${qr.condominio}'),
                    subtitle: Text('Vence: ${qr.expira} | Usos: ${qr.usosRestantes}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/qr-casa', extra: {
                        'casa': 'Casa ${qr.casa}',
                        'condominio': qr.condominio,
                      });
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
