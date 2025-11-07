import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/back_handler.dart';

import '../../models/solicitud_model.dart';
import '../../services/solicitud_remote_service.dart';
import '../../services/condominio_service.dart';


class SolicitudQrScreen extends StatefulWidget {
  const SolicitudQrScreen({super.key});

  @override
  State<SolicitudQrScreen> createState() => _SolicitudQrScreenState();
}

class _SolicitudQrScreenState extends State<SolicitudQrScreen> {
  final _nombreApellidosController = TextEditingController();
  final _ciController = TextEditingController();


  String? _condominioSeleccionado;
  int? _casaSeleccionada;


  @override
  void initState() {
    super.initState();
    _cargarDatosVisitante();
  }
  
  Future<void> _cargarDatosVisitante() async {
    final prefs = await SharedPreferences.getInstance();
    _nombreApellidosController.text = prefs.getString('visitante_nombre') ?? '';
    _ciController.text = prefs.getString('visitante_ci') ?? '';
    setState(() {});
  }

  void _enviarSolicitud() async {
    final nombreApellidos = _nombreApellidosController.text.trim();
    final ci = _ciController.text.trim();

    if (_condominioSeleccionado == null || _casaSeleccionada == null || nombreApellidos.isEmpty || ci.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    final solicitud = SolicitudModel(
      nombre: nombreApellidos,
      apellidos: '', // Deja vacío o elimínalo si no se usa
      ci: ci,
      condominio: _condominioSeleccionado!,
      casaNumero: _casaSeleccionada!,
      fecha: DateTime.now(),
      estado: 'pendiente',
    );

//TODO: mi qr modificar limite

    try {
      // Guarda datos del visitante localmente para mostrarlos en Mi QR
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('visitante_nombre', nombreApellidos);
      await prefs.setString('visitante_ci', ci);

      await SolicitudRemoteService.guardarSolicitud(solicitud);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada')),
      );

      context.go('/mi-qr');
    } on FirebaseException catch (e) {
      // Error de Firestore: muestra motivo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error inesperado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud de ingreso'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/acceso-general'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.assignment_ind_outlined),
                      SizedBox(width: 8),
                      Text('Completa tu solicitud', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Condominio'),
                  StreamBuilder<List<String>>(
              stream: CondominioService.streamCondominios(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snapshot.data!;
                if (lista.isEmpty) return const Text('No hay condominios registrados');
                return DropdownButton<String>(
                  value: _condominioSeleccionado != null && lista.contains(_condominioSeleccionado) ? _condominioSeleccionado : null,
                  hint: const Text('Selecciona un condominio'),
                  isExpanded: true,
                  items: lista.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (value) {
                    setState(() {
                      _condominioSeleccionado = value;
                      _casaSeleccionada = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            if (_condominioSeleccionado != null) ...[
              const Text('Casa'),
              StreamBuilder<List<int>>(
                stream: CondominioService.streamCasas(_condominioSeleccionado!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final casas = snapshot.data!;
                  if (casas.isEmpty) return const Text('Sin casas registradas');
                  return DropdownButton<int>(
                    value: _casaSeleccionada != null && casas.contains(_casaSeleccionada) ? _casaSeleccionada : null,
                    hint: const Text('Selecciona una casa'),
                    isExpanded: true,
                    items: casas.map((c) => DropdownMenuItem(value: c, child: Text('Casa $c'))).toList(),
                    onChanged: (value) {
                      setState(() {
                        _casaSeleccionada = value;
                      });
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nombreApellidosController,
              decoration: const InputDecoration(labelText: 'Nombre y Apellidos'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ciController,
              decoration: const InputDecoration(labelText: 'Carnet de identidad'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _enviarSolicitud,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    ),
    ),
    ),
    ),
  );
  }
}
