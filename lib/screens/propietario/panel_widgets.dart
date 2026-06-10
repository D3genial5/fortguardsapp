import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Diálogo para que el propietario modifique el acceso de un invitado ya
/// aceptado (número de usos restantes). Localiza el documento correspondiente
/// en la colección `access_requests` y devuelve `true` si guardó cambios.
class ModificarAccesoDialog extends StatefulWidget {
  final String nombre;
  final int usosActuales;
  final Map<String, dynamic> data;
  final String condominio;
  final String casaNumero;
  final String? codigoCasa;

  const ModificarAccesoDialog({
    super.key,
    required this.nombre,
    required this.usosActuales,
    required this.data,
    required this.condominio,
    required this.casaNumero,
    this.codigoCasa,
  });

  @override
  State<ModificarAccesoDialog> createState() => _ModificarAccesoDialogState();
}

class _ModificarAccesoDialogState extends State<ModificarAccesoDialog> {
  late final TextEditingController _usosController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _usosController =
        TextEditingController(text: widget.usosActuales.toString());
  }

  @override
  void dispose() {
    _usosController.dispose();
    super.dispose();
  }

  /// Busca el documento del invitado. Prioriza el `codigoQr` (único); si no
  /// está disponible, cae a la combinación condominio + casa + C.I. + estado.
  Future<DocumentReference<Map<String, dynamic>>?> _buscarDoc() async {
    final col = FirebaseFirestore.instance.collection('access_requests');

    final codigoQr = widget.data['codigoQr'] as String?;
    if (codigoQr != null && codigoQr.isNotEmpty) {
      final q = await col.where('codigoQr', isEqualTo: codigoQr).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.reference;
    }

    final q = await col
        .where('condominio', isEqualTo: widget.condominio)
        .where('casaNumero', isEqualTo: widget.casaNumero)
        .where('ci', isEqualTo: widget.data['ci'])
        .where('estado', isEqualTo: 'aceptada')
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.reference;

    return null;
  }

  Future<void> _guardar() async {
    final nuevosUsos = int.tryParse(_usosController.text.trim());
    if (nuevosUsos == null || nuevosUsos < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un número de usos válido')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final ref = await _buscarDoc();
      if (!mounted) return;
      if (ref == null) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la solicitud del invitado'),
          ),
        );
        return;
      }

      await ref.update({
        'usosRestantes': nuevosUsos,
        'codigoUsos': nuevosUsos,
        'tipoAcceso': 'usos',
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modificar acceso de ${widget.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usosController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Usos restantes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
