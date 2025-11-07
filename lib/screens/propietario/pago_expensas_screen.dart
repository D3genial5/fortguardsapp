import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../../models/propietario_model.dart';
import '../../widgets/back_handler.dart';

class PagoExpensasScreen extends StatefulWidget {
  final PropietarioModel propietario;

  const PagoExpensasScreen({
    super.key,
    required this.propietario,
  });

  @override
  State<PagoExpensasScreen> createState() => _PagoExpensasScreenState();
}

class _PagoExpensasScreenState extends State<PagoExpensasScreen> {
  bool _cargando = false;
  String? _estadoExpensa;
  double? _montoExpensa;
  DateTime? _fechaVencimiento;
  String? _qrPagoUrl;
  final List<Map<String, dynamic>> _historialPagos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosExpensa();
  }

  Future<void> _cargarDatosExpensa() async {
    setState(() {
      _cargando = true;
    });

    try {
      // Cargar datos de la expensa actual
      final docCasa = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.propietario.condominio)
          .collection('casas')
          .doc(widget.propietario.casa.numero.toString())
          .get();

      if (docCasa.exists) {
        final data = docCasa.data()!;
        setState(() {
          _estadoExpensa = data['estadoExpensa']?.toString();
          _montoExpensa = (data['montoExpensa'] as num?)?.toDouble();
          _fechaVencimiento = (data['fechaVencimiento'] as Timestamp?)?.toDate();
        });
      }
      
      // Cargar QR de pago del condominio
      final docCondominio = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.propietario.condominio)
          .get();
          
      if (docCondominio.exists) {
        final data = docCondominio.data()!;
        setState(() {
          _qrPagoUrl = data['qrPagoUrl']?.toString();
        });
      }

      // Cargar historial de pagos
      final pagosSnapshot = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.propietario.condominio)
          .collection('casas')
          .doc(widget.propietario.casa.numero.toString())
          .collection('pagos')
          .orderBy('fecha', descending: true)
          .get();

      final pagos = pagosSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'monto': (data['monto'] as num?)?.toDouble() ?? 0.0,
          'fecha': (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'concepto': data['concepto']?.toString() ?? 'Expensa mensual',
          'comprobante': data['comprobante']?.toString(),
        };
      }).toList();

      setState(() {
        _historialPagos.clear();
        _historialPagos.addAll(pagos);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  Future<void> _registrarPago() async {
    if (!mounted) return;
    
    final formKey = GlobalKey<FormState>();
    final montoController = TextEditingController(
        text: _montoExpensa?.toString() ?? '');
    final conceptoController = TextEditingController(text: 'Expensa mensual');
    final comprobanteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: montoController,
                  decoration: const InputDecoration(labelText: 'Monto'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese un monto';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Ingrese un número válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: conceptoController,
                  decoration: const InputDecoration(labelText: 'Concepto'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese un concepto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: comprobanteController,
                  decoration: const InputDecoration(
                      labelText: 'Número de comprobante (opcional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                
                setState(() {
                  _cargando = true;
                });

                // Capturar el ScaffoldMessengerState ANTES de cualquier operación asíncrona
                // para evitar el uso de BuildContext a través de async gaps
                final scaffoldMessengerState = ScaffoldMessenger.of(context);
                
                try {
                  // Registrar el pago
                  await FirebaseFirestore.instance
                      .collection('condominios')
                      .doc(widget.propietario.condominio)
                      .collection('casas')
                      .doc(widget.propietario.casa.numero.toString())
                      .collection('pagos')
                      .add({
                    'monto': double.parse(montoController.text),
                    'fecha': Timestamp.now(),
                    'concepto': conceptoController.text,
                    'comprobante': comprobanteController.text,
                  });

                  // Actualizar estado de la expensa
                  await FirebaseFirestore.instance
                      .collection('condominios')
                      .doc(widget.propietario.condominio)
                      .collection('casas')
                      .doc(widget.propietario.casa.numero.toString())
                      .update({
                    'estadoExpensa': 'Pagado',
                    'fechaPago': Timestamp.now(),
                  });
                
                  // Recargar datos
                  await _cargarDatosExpensa();

                  // Verificar que el widget sigue montado antes de mostrar el SnackBar
                  if (mounted) {
                    scaffoldMessengerState.showSnackBar(
                      const SnackBar(content: Text('Pago registrado con éxito')),
                    );
                  }
                } catch (e) {
                  // Verificar que el widget sigue montado antes de mostrar el SnackBar de error
                  if (mounted) {
                    scaffoldMessengerState.showSnackBar(
                      SnackBar(content: Text('Error al registrar pago: $e')),
                    );
                  }
                } finally {
                  setState(() {
                    _cargando = false;
                  });
                }
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
  
  Future<void> _guardarQREnGaleria() async {
    if (_qrPagoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay QR disponible para descargar'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Descargar la imagen
      final response = await http.get(Uri.parse(_qrPagoUrl!));
      
      if (response.statusCode == 200) {
        // Guardar en galería usando gal (maneja permisos automáticamente)
        final nombre = 'QR_Expensas_${widget.propietario.condominio}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Gal.putImageBytes(
          response.bodyBytes,
          name: nombre,
        );
        
        // Cerrar diálogo de carga
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR guardado en galería exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Error al descargar imagen');
      }
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar QR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Pago de Expensas'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatosExpensa,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tarjeta de estado actual mejorada
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _estadoExpensa == 'Pagado' 
                                ? Colors.green.shade400
                                : _estadoExpensa == 'pendiente'
                                    ? Colors.orange.shade400
                                    : Colors.red.shade400,
                            _estadoExpensa == 'Pagado'
                                ? Colors.green.shade600
                                : _estadoExpensa == 'pendiente'
                                    ? Colors.orange.shade600
                                    : Colors.red.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Estado Actual',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _estadoExpensa ?? 'No disponible',
                                    style: TextStyle(
                                      color: _estadoExpensa == 'Pagado'
                                          ? Colors.green.shade700
                                          : _estadoExpensa == 'pendiente'
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.home, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Casa ${widget.propietario.casa.numero}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.location_city, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  widget.propietario.condominio,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white30, thickness: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Monto a pagar',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${_montoExpensa?.toStringAsFixed(2) ?? "0.00"}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_fechaVencimiento != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Vencimiento',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatearFecha(_fechaVencimiento!),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // QR de pago si existe
                    if (_qrPagoUrl != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.qr_code_2,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Código QR para Pago',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Escanea para pagar tu expensa',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _qrPagoUrl!,
                                  height: 250,
                                  width: 250,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      height: 250,
                                      width: 250,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 250,
                                      width: 250,
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: colorScheme.onErrorContainer,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Error al cargar QR',
                                            style: TextStyle(
                                              color: colorScheme.onErrorContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Botón para guardar QR en galería
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _guardarQREnGaleria,
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Guardar QR en Galería'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Historial de pagos
                    const Text(
                      'Historial de Pagos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_historialPagos.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No hay pagos registrados',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _historialPagos.length,
                        itemBuilder: (context, index) {
                          final pago = _historialPagos[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(pago['concepto'] as String),
                              subtitle: Text(
                                  'Fecha: ${_formatearFecha(pago['fecha'] as DateTime)}'),
                              trailing: Text(
                                '\$${(pago['monto'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: _estadoExpensa != 'Pagado'
          ? FloatingActionButton.extended(
              onPressed: _registrarPago,
              icon: const Icon(Icons.payment),
              label: const Text('Registrar Pago'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : null,
      ),
    );
  }
}
