import 'package:flutter/material.dart';
import '../../widgets/back_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/propietario_model.dart';

class GestionarSolicitudesScreen extends StatefulWidget {
  final PropietarioModel propietario;

  const GestionarSolicitudesScreen({
    super.key,
    required this.propietario,
  });

  @override
  State<GestionarSolicitudesScreen> createState() => _GestionarSolicitudesScreenState();
}

class _GestionarSolicitudesScreenState extends State<GestionarSolicitudesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Invitados'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'Pendientes', icon: Icon(Icons.pending)),
            Tab(text: 'Aprobadas', icon: Icon(Icons.check_circle)),
            Tab(text: 'Rechazadas', icon: Icon(Icons.cancel)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSolicitudesList('pendiente'),
          _buildSolicitudesList('aceptada'),
          _buildSolicitudesList('rechazada'),
        ],
      ),
      ),
    );
  }

  Widget _buildSolicitudesList(String estado) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('access_requests')
          .where('condominio', isEqualTo: widget.propietario.condominio)
          .where('casaNumero', isEqualTo: widget.propietario.casa.numero)
          .where('estado', isEqualTo: estado)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Ordenar manualmente por fecha (más recientes primero)
        docs.sort((a, b) {
          try {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            
            final fechaA = _parseFecha(dataA['fecha']);
            final fechaB = _parseFecha(dataB['fecha']);
            
            return fechaB.compareTo(fechaA); // Más recientes primero
          } catch (e) {
            return 0; // Si hay error, mantener orden original
          }
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyIcon(estado),
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(estado),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getStatusColor(estado),
                          child: Text(
                            _getInitials(data['nombre'], data['apellidos']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['nombre'] ?? 'Sin nombre'} ${data['apellidos'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'CI: ${data['ci'] ?? 'Sin CI'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(estado).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(estado),
                            style: TextStyle(
                              color: _getStatusColor(estado),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatFecha(data['fecha']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (data['codigoUsos'] != null) ..._buildInfoAcceso(data),
                      ],
                    ),
                    if (estado == 'pendiente') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rechazarSolicitud(docs[index].id, data),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text(
                                'Rechazar',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _aprobarSolicitud(docs[index].id, data),
                              icon: const Icon(Icons.check),
                              label: const Text('Aprobar'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getEmptyIcon(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.inbox;
      case 'aceptada':
        return Icons.check_circle_outline;
      case 'rechazada':
        return Icons.cancel_outlined;
      default:
        return Icons.folder_open;
    }
  }

  String _getEmptyMessage(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'No hay solicitudes pendientes';
      case 'aceptada':
        return 'No hay solicitudes aprobadas';
      case 'rechazada':
        return 'No hay solicitudes rechazadas';
      default:
        return 'No hay solicitudes';
    }
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'aceptada':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Widget> _buildInfoAcceso(Map<String, dynamic> data) {
    final tipoAcceso = data['tipoAcceso'] ?? 'usos';
    final usos = data['codigoUsos'] ?? 1;
    
    List<Widget> widgets = [];
    
    switch (tipoAcceso) {
      case 'usos':
        widgets.addAll([
          const SizedBox(width: 16),
          Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            'Usos: $usos',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ]);
        break;
        
      case 'tiempo':
        final fechaExpiracion = data['fechaExpiracion'];
        final duracionValor = data['duracionValor'] ?? 1;
        final duracionUnidad = data['duracionUnidad'] ?? 'meses';
        
        widgets.addAll([
          const SizedBox(width: 16),
          Icon(Icons.schedule, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 4),
          Text(
            'Por $duracionValor $duracionUnidad',
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 12,
            ),
          ),
        ]);
        
        if (fechaExpiracion != null) {
          try {
            final expiracion = DateTime.parse(fechaExpiracion);
            final ahora = DateTime.now();
            final diferencia = expiracion.difference(ahora);
            
            if (diferencia.isNegative) {
              widgets.addAll([
                const SizedBox(width: 8),
                Icon(Icons.warning, size: 16, color: Colors.red[600]),
                const SizedBox(width: 2),
                Text(
                  'Expirado',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]);
            } else {
              String tiempoRestante;
              if (diferencia.inDays > 0) {
                tiempoRestante = '${diferencia.inDays}d restantes';
              } else if (diferencia.inHours > 0) {
                tiempoRestante = '${diferencia.inHours}h restantes';
              } else {
                tiempoRestante = '${diferencia.inMinutes}m restantes';
              }
              
              widgets.addAll([
                const SizedBox(width: 8),
                Text(
                  '($tiempoRestante)',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ]);
            }
          } catch (e) {
            // Error al parsear fecha, mostrar información básica
          }
        }
        break;
        
      case 'indefinido':
        widgets.addAll([
          const SizedBox(width: 16),
          Icon(Icons.all_inclusive, size: 16, color: Colors.purple[600]),
          const SizedBox(width: 4),
          Text(
            'Acceso indefinido',
            style: TextStyle(
              color: Colors.purple[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]);
        break;
        
      default:
        // Fallback para compatibilidad con datos antiguos
        widgets.addAll([
          const SizedBox(width: 16),
          Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            'Usos: $usos',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ]);
    }
    
    return widgets;
  }

  String _getStatusText(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'aceptada':
        return 'APROBADA';
      case 'rechazada':
        return 'RECHAZADA';
      default:
        return 'DESCONOCIDO';
    }
  }

  String _getInitials(dynamic nombre, dynamic apellidos) {
    try {
      final nombreStr = (nombre ?? '').toString().trim();
      final apellidosStr = (apellidos ?? '').toString().trim();
      
      String iniciales = '';
      
      if (nombreStr.isNotEmpty) {
        iniciales += nombreStr[0].toUpperCase();
      }
      
      if (apellidosStr.isNotEmpty) {
        iniciales += apellidosStr[0].toUpperCase();
      }
      
      return iniciales.isEmpty ? '?' : iniciales;
    } catch (e) {
      return '?';
    }
  }

  DateTime _parseFecha(dynamic fecha) {
    try {
      if (fecha is Timestamp) {
        return fecha.toDate();
      } else if (fecha is String) {
        return DateTime.parse(fecha);
      } else {
        return DateTime.now(); // Fecha por defecto si no se puede parsear
      }
    } catch (e) {
      return DateTime.now(); // Fecha por defecto en caso de error
    }
  }

  String _formatFecha(dynamic fecha) {
    try {
      DateTime fechaDateTime;
      if (fecha is Timestamp) {
        fechaDateTime = fecha.toDate();
      } else if (fecha is String) {
        fechaDateTime = DateTime.parse(fecha);
      } else {
        return 'Fecha desconocida';
      }

      final now = DateTime.now();
      final difference = now.difference(fechaDateTime);

      if (difference.inDays > 0) {
        return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'Hace un momento';
      }
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  Future<void> _aprobarSolicitud(String docId, Map<String, dynamic> data) async {
    try {
      final resultado = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _buildAprobarDialog(data),
      );
      
      if (resultado != null) {
        Map<String, dynamic> updateData = {
          'estado': 'aceptada',
          'fechaAprobacion': FieldValue.serverTimestamp(),
          'codigoUsos': resultado['usos'],
          'tipoAcceso': resultado['tipoAcceso'] ?? 'usos',
        };
        
        // Agregar fecha de expiración si es por tiempo
        if (resultado['fechaExpiracion'] != null) {
          updateData['fechaExpiracion'] = resultado['fechaExpiracion'];
        }
        
        // Agregar información de duración si es por tiempo
        if (resultado['duracionValor'] != null) {
          updateData['duracionValor'] = resultado['duracionValor'];
          updateData['duracionUnidad'] = resultado['duracionUnidad'];
        }
        
        await FirebaseFirestore.instance
            .collection('access_requests')
            .doc(docId)
            .update(updateData);
        
        if (mounted) {
          String mensaje = 'Solicitud aprobada exitosamente';
          
          switch (resultado['tipoAcceso']) {
            case 'usos':
              mensaje += ' con ${resultado['usos']} ${resultado['usos'] == 1 ? "uso" : "usos"}';
              break;
            case 'tiempo':
              mensaje += ' por ${resultado['duracionValor']} ${resultado['duracionUnidad']}';
              break;
            case 'indefinido':
              mensaje += ' con acceso indefinido';
              break;
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rechazarSolicitud(String solicitudId, Map<String, dynamic> data) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Confirmar rechazo
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rechazar solicitud'),
          content: Text('¿Estás seguro de rechazar la solicitud de ${data['nombre']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      // Actualizar la solicitud en Firestore
      await FirebaseFirestore.instance
          .collection('access_requests')
          .doc(solicitudId)
          .update({
        'estado': 'rechazada',
        'fechaRechazo': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Solicitud de ${data['nombre']} rechazada'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al rechazar solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAprobarDialog(Map<String, dynamic> data) {
    String tipoAcceso = 'usos';
    int usos = 1;
    int duracionValor = 1;
    String duracionUnidad = 'meses';
    
    return StatefulBuilder(
      builder: (context, setStateDialog) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Aprobar solicitud',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${data['nombre']} ${data['apellidos'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Tipo de acceso
                const Text(
                  'Tipo de acceso:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Opciones de tipo
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      _buildTipoAccesoTileApprove(
                        'usos',
                        Icons.repeat,
                        'Por número de usos',
                        'Limitar la cantidad de veces que puede usar el código',
                        tipoAcceso,
                        (valor) => setStateDialog(() => tipoAcceso = valor),
                      ),
                      const Divider(height: 1),
                      _buildTipoAccesoTileApprove(
                        'tiempo',
                        Icons.schedule,
                        'Por tiempo limitado',
                        'El código expira después de un período específico',
                        tipoAcceso,
                        (valor) => setStateDialog(() => tipoAcceso = valor),
                      ),
                      const Divider(height: 1),
                      _buildTipoAccesoTileApprove(
                        'indefinido',
                        Icons.all_inclusive,
                        'Acceso indefinido',
                        'Sin límites de uso ni tiempo (ideal para familia)',
                        tipoAcceso,
                        (valor) => setStateDialog(() => tipoAcceso = valor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Configuración específica
                if (tipoAcceso == 'usos') ..._buildConfiguracionUsosApprove(usos, (valor) => setStateDialog(() => usos = valor)),
                if (tipoAcceso == 'tiempo') ..._buildConfiguracionTiempoApprove(duracionValor, duracionUnidad, 
                  (valor) => setStateDialog(() => duracionValor = valor),
                  (unidad) => setStateDialog(() => duracionUnidad = unidad),
                ),
                if (tipoAcceso == 'indefinido') ..._buildConfiguracionIndefinidoApprove(),
                
                const SizedBox(height: 24),
                
                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Map<String, dynamic> resultado = {'usos': usos};
                          
                          switch (tipoAcceso) {
                            case 'usos':
                              resultado = {
                                'usos': usos,
                                'tipoAcceso': 'usos',
                                'fechaExpiracion': null,
                              };
                              break;
                            case 'tiempo':
                              final ahora = DateTime.now();
                              DateTime expiracion;
                              
                              switch (duracionUnidad) {
                                case 'días':
                                  expiracion = ahora.add(Duration(days: duracionValor));
                                  break;
                                case 'semanas':
                                  expiracion = ahora.add(Duration(days: duracionValor * 7));
                                  break;
                                case 'meses':
                                  expiracion = DateTime(ahora.year, ahora.month + duracionValor, ahora.day);
                                  break;
                                case 'años':
                                  expiracion = DateTime(ahora.year + duracionValor, ahora.month, ahora.day);
                                  break;
                                default:
                                  expiracion = ahora.add(Duration(days: 30));
                              }
                              
                              resultado = {
                                'usos': 999999,
                                'tipoAcceso': 'tiempo',
                                'fechaExpiracion': expiracion.toIso8601String(),
                                'duracionValor': duracionValor,
                                'duracionUnidad': duracionUnidad,
                              };
                              break;
                            case 'indefinido':
                              resultado = {
                                'usos': 999999,
                                'tipoAcceso': 'indefinido',
                                'fechaExpiracion': null,
                              };
                              break;
                          }
                          
                          Navigator.pop(context, resultado);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipoAccesoTileApprove(
    String valor,
    IconData icono,
    String titulo,
    String descripcion,
    String valorActual,
    Function(String) onChanged,
  ) {
    final isSelected = valor == valorActual;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(valor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icono,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.green : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConfiguracionUsosApprove(int usos, Function(int) onChanged) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cantidad de usos:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: usos.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$usos ${usos == 1 ? "uso" : "usos"}',
              activeColor: Colors.green,
              onChanged: (value) => onChanged(value.round()),
            ),
            Center(
              child: Text(
                '$usos ${usos == 1 ? "uso" : "usos"}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConfiguracionTiempoApprove(int valor, String unidad, Function(int) onValorChanged, Function(String) onUnidadChanged) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Duración del acceso:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Slider(
                        value: valor.toDouble(),
                        min: 1,
                        max: unidad == 'días' ? 30 : unidad == 'semanas' ? 12 : unidad == 'meses' ? 12 : 5,
                        divisions: (unidad == 'días' ? 29 : unidad == 'semanas' ? 11 : unidad == 'meses' ? 11 : 4),
                        label: '$valor',
                        activeColor: Colors.blue,
                        onChanged: (value) => onValorChanged(value.round()),
                      ),
                      Text(
                        '$valor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: unidad,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        items: ['días', 'semanas', 'meses', 'años'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            onUnidadChanged(newValue);
                            if (newValue == 'días' && valor > 30) onValorChanged(30);
                            if (newValue == 'semanas' && valor > 12) onValorChanged(12);
                            if (newValue == 'meses' && valor > 12) onValorChanged(12);
                            if (newValue == 'años' && valor > 5) onValorChanged(5);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Expira en $valor $unidad',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConfiguracionIndefinidoApprove() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.all_inclusive,
              color: Colors.purple,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso sin restricciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Este invitado podrá usar el código las veces que necesite, sin límite de tiempo. Ideal para familiares cercanos.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
