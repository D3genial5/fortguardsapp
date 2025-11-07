import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/back_handler.dart';

class RegistroVisitaScreen extends StatefulWidget {
  const RegistroVisitaScreen({super.key});

  @override
  State<RegistroVisitaScreen> createState() => _RegistroVisitaScreenState();
}

class _RegistroVisitaScreenState extends State<RegistroVisitaScreen> {
  final _nombreController = TextEditingController();
  final _ciController = TextEditingController();
  final _placaController = TextEditingController();

  Future<void> _guardarDatosYContinuar() async {
    final nombre = _nombreController.text.trim();
    final ci = _ciController.text.trim();

    if (nombre.isEmpty || ci.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa al menos nombre y CI')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('visitante_nombre', nombre);
    await prefs.setString('visitante_ci', ci);


    if (!mounted) return;
    context.go('/acceso-general');
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Registro de Visitante', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: Column(
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'NOMBRE COMPLETO*',
                  border: OutlineInputBorder(borderSide: BorderSide(width: .5)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _ciController,
                      decoration: const InputDecoration(
                        labelText: 'C.I.*',
                        isDense: true,
                        border: OutlineInputBorder(borderSide: BorderSide(width: .5)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _placaController,
                      decoration: const InputDecoration(
                        labelText: 'PLACA',
                        isDense: true,
                        border: OutlineInputBorder(borderSide: BorderSide(width: .5)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: .8,
                children: [
                  _buildFotoInput('C.I.\nFRENTE'),
                  _buildFotoInput('C.I.\nREVERSO'),
                  _buildFotoInput('PLACA /\nAUTO'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _guardarDatosYContinuar,
                  child: const Text('Siguiente'),
                ),
              )
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildFotoInput(String label) {
    return Column(
      children: [
        CircleAvatar(
        radius: 28,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.camera_alt_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
      ],
    );
  }
}
