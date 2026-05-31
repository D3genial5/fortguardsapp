import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../widgets/back_handler.dart';

import '../../models/solicitud_model.dart';
import '../../services/solicitud_remote_service.dart';
import '../../services/condominio_service.dart';
import '../../services/secure_storage_service.dart';


class SolicitudQrScreen extends StatefulWidget {
  const SolicitudQrScreen({super.key});

  @override
  State<SolicitudQrScreen> createState() => _SolicitudQrScreenState();
}

class _SolicitudQrScreenState extends State<SolicitudQrScreen> {
  final _nombreApellidosController = TextEditingController();
  final _ciController = TextEditingController();

  bool _nombreBloqueado = false;
  bool _ciBloqueado = false;
  bool _isSubmitting = false;


  String? _condominioSeleccionado;
  int? _casaSeleccionada;


  @override
  void initState() {
    super.initState();
    _cargarDatosVisitante();
  }

  @override
  void dispose() {
    _nombreApellidosController.dispose();
    _ciController.dispose();
    super.dispose();
  }
  
  Future<void> _cargarDatosVisitante() async {
    final nombre = await SecureStorageService.getVisitanteNombre() ?? '';
    final ci = await SecureStorageService.getVisitanteCi() ?? '';
    _nombreApellidosController.text = nombre;
    _ciController.text = ci;
    _nombreBloqueado = nombre.isNotEmpty;
    _ciBloqueado = ci.isNotEmpty;
    setState(() {});
  }

  Future<void> _enviarSolicitud() async {
    if (_isSubmitting) return;

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

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Guarda datos del visitante en almacenamiento seguro
      await SecureStorageService.saveVisitanteNombre(nombreApellidos);
      await SecureStorageService.saveVisitanteCi(ci);

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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = constraints.maxWidth < 380 ? 12.0 : 16.0;

            return Padding(
              padding: EdgeInsets.all(sidePadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        shrinkWrap: true,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Icon(Icons.assignment_ind_outlined),
                      Text(
                        'Completa tu solicitud',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Condominio'),
                  StreamBuilder<List<String>>(
              stream: CondominioService.streamCondominios(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  );
                }
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
                  if (snapshot.hasError) {
                    return Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    );
                  }
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
              readOnly: _nombreBloqueado,
              decoration: InputDecoration(
                labelText: 'Nombre y Apellidos',
                suffixIcon: _nombreBloqueado
                    ? const Icon(Icons.lock_rounded, size: 18)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ciController,
              readOnly: _ciBloqueado,
              decoration: InputDecoration(
                labelText: 'Carnet de identidad',
                suffixIcon: _ciBloqueado
                    ? const Icon(Icons.lock_rounded, size: 18)
                    : null,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _enviarSolicitud,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmitting ? 'Enviando...' : 'Enviar solicitud',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  }
}
