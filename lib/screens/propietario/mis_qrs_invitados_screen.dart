import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import '../../models/propietario_model.dart';
import '../../models/qr_invitado_model.dart';
import '../../services/qr_service.dart';
import '../../widgets/back_handler.dart';

class MisQrsInvitadosScreen extends StatefulWidget {
  final PropietarioModel propietario;

  const MisQrsInvitadosScreen({
    super.key,
    required this.propietario,
  });

  @override
  State<MisQrsInvitadosScreen> createState() => _MisQrsInvitadosScreenState();
}

class _MisQrsInvitadosScreenState extends State<MisQrsInvitadosScreen> {
  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis QR de Invitados'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _mostrarDialogoCrearQr,
              tooltip: 'Crear nuevo QR',
            ),
          ],
        ),
        body: StreamBuilder<List<QrInvitadoModel>>(
          stream: QrService.obtenerQrsPorPropietario(
            condominio: widget.propietario.condominio,
            casaNumero: widget.propietario.casa.numero,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final qrs = snapshot.data ?? [];
            
            if (qrs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No tienes QR de invitados', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _mostrarDialogoCrearQr,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear QR'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: qrs.length,
              itemBuilder: (context, index) => _buildQrCard(qrs[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQrCard(QrInvitadoModel qr) {
    final color = _getColorEstado(qr.estado);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _mostrarDetallesQr(qr),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getIconoTipo(qr.tipo), color: color, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(qr.invitadoNombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('CI: ${qr.invitadoCi}', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Chip(label: Text(qr.mensajeEstado), backgroundColor: color.withValues(alpha: 0.2)),
                ],
              ),
              const SizedBox(height: 12),
              Text(qr.tipoDescripcion),
              if (qr.placaVehiculo != null) Text('Placa: ${qr.placaVehiculo}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: qr.estado == EstadoQr.activo ? () => _descargarQr(qr) : null,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Descargar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mostrarDetallesQr(qr),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Ver'),
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

  Color _getColorEstado(EstadoQr estado) {
    switch (estado) {
      case EstadoQr.activo: return Colors.green;
      case EstadoQr.sinUsos: return Colors.orange;
      case EstadoQr.expirado: return Colors.red;
      case EstadoQr.revocado: return Colors.grey;
    }
  }

  IconData _getIconoTipo(TipoQr tipo) {
    switch (tipo) {
      case TipoQr.permanente: return Icons.all_inclusive;
      case TipoQr.porTiempo: return Icons.schedule;
      case TipoQr.porUso: return Icons.repeat;
      case TipoQr.mixto: return Icons.compare_arrows;
    }
  }

  Future<void> _mostrarDialogoCrearQr() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoCrearQr(
        condominio: widget.propietario.condominio,
        casaNumero: widget.propietario.casa.numero,
        propietarioId: widget.propietario.codigoCasa,
      ),
    );

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ QR creado exitosamente'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _mostrarDetallesQr(QrInvitadoModel qr) async {
    await showDialog(
      context: context,
      builder: (context) => DialogoDetallesQr(qr: qr),
    );
  }

  Future<void> _descargarQr(QrInvitadoModel qr) async {
    try {
      final qrValidationResult = await QrPainter(
        data: qr.codigo,
        version: QrVersions.auto,
        gapless: false,
      ).toImageData(300);

      if (qrValidationResult == null) throw Exception('No se pudo generar QR');

      await Gal.putImageBytes(
        qrValidationResult.buffer.asUint8List(),
        name: 'QR_${qr.invitadoNombre.replaceAll(' ', '_')}.png',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ QR guardado en galería'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class DialogoCrearQr extends StatefulWidget {
  final String condominio;
  final int casaNumero;
  final String propietarioId;

  const DialogoCrearQr({
    super.key,
    required this.condominio,
    required this.casaNumero,
    required this.propietarioId,
  });

  @override
  State<DialogoCrearQr> createState() => _DialogoCrearQrState();
}

class _DialogoCrearQrState extends State<DialogoCrearQr> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ciController = TextEditingController();
  final _placaController = TextEditingController();
  
  TipoQr _tipo = TipoQr.porUso;
  int _usos = 5;
  DateTime? _expira;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _ciController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Crear QR de Invitado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre completo *', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _ciController,
                  decoration: const InputDecoration(labelText: 'CI *', prefixIcon: Icon(Icons.badge)),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _placaController,
                  decoration: const InputDecoration(labelText: 'Placa (opcional)', prefixIcon: Icon(Icons.directions_car)),
                ),
                const SizedBox(height: 24),
                
                const Text('Tipo de QR:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                
                ...TipoQr.values.map((tipo) => RadioListTile<TipoQr>(
                  title: Text(_getNombreTipo(tipo)),
                  subtitle: Text(_getDescripcionTipo(tipo)),
                  value: tipo,
                  groupValue: _tipo,
                  onChanged: (v) => setState(() => _tipo = v!),
                )),
                
                const SizedBox(height: 16),
                
                if (_tipo == TipoQr.porUso || _tipo == TipoQr.mixto) ...[
                  Text('Cantidad de usos: $_usos', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: _usos.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_usos',
                    onChanged: (v) => setState(() => _usos = v.round()),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (_tipo == TipoQr.porTiempo || _tipo == TipoQr.mixto) ...[
                  const Text('Fecha de expiración:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (fecha != null) setState(() => _expira = fecha);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_expira != null ? '${_expira!.day}/${_expira!.month}/${_expira!.year}' : 'Seleccionar'),
                  ),
                  const SizedBox(height: 16),
                ],
                
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _crearQr,
                        child: _isLoading ? const CircularProgressIndicator() : const Text('Crear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNombreTipo(TipoQr tipo) {
    switch (tipo) {
      case TipoQr.permanente: return 'Permanente';
      case TipoQr.porUso: return 'Por uso';
      case TipoQr.porTiempo: return 'Por tiempo';
      case TipoQr.mixto: return 'Mixto';
    }
  }

  String _getDescripcionTipo(TipoQr tipo) {
    switch (tipo) {
      case TipoQr.permanente: return 'Sin límites';
      case TipoQr.porUso: return 'Limitar cantidad de usos';
      case TipoQr.porTiempo: return 'Expira en una fecha';
      case TipoQr.mixto: return 'Límite de usos y tiempo';
    }
  }

  Future<void> _crearQr() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_tipo == TipoQr.porTiempo || _tipo == TipoQr.mixto) && _expira == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha de expiración'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final codigo = 'INV_${widget.condominio}_${widget.casaNumero}_${DateTime.now().millisecondsSinceEpoch}';

      final qr = QrInvitadoModel(
        codigo: codigo,
        condominio: widget.condominio,
        casaNumero: widget.casaNumero,
        tipo: _tipo,
        invitadoNombre: _nombreController.text.trim(),
        invitadoCi: _ciController.text.trim(),
        placaVehiculo: _placaController.text.trim().isEmpty ? null : _placaController.text.trim(),
        usosRestantes: (_tipo == TipoQr.porUso || _tipo == TipoQr.mixto) ? _usos : null,
        expira: (_tipo == TipoQr.porTiempo || _tipo == TipoQr.mixto) ? _expira : null,
        creadoPor: widget.propietarioId,
        creadoEn: DateTime.now(),
      );

      await QrService.crearQrInvitado(qr);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class DialogoDetallesQr extends StatelessWidget {
  final QrInvitadoModel qr;

  const DialogoDetallesQr({super.key, required this.qr});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(data: qr.codigo, version: QrVersions.auto, size: 200),
            ),
            const SizedBox(height: 16),
            Text(qr.invitadoNombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('CI: ${qr.invitadoCi}'),
            if (qr.placaVehiculo != null) Text('Placa: ${qr.placaVehiculo}'),
            const SizedBox(height: 16),
            Chip(label: Text(qr.mensajeEstado)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (qr.estado == EstadoQr.activo) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Revocar QR'),
                            content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Revocar'),
                              ),
                            ],
                          ),
                        );

                        if (confirmar == true) {
                          await QrService.revocarQr(qr.codigo);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ QR revocado'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      },
                      child: const Text('Revocar', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
