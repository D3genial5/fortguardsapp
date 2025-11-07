import 'package:flutter/material.dart';
import '../../widgets/back_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/propietario_model.dart';

class ReservasScreen extends StatefulWidget {
  final PropietarioModel propietario;

  const ReservasScreen({
    super.key,
    required this.propietario,
  });

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = false;
  List<Map<String, dynamic>> _misReservas = [];
  List<Map<String, dynamic>> _areasComunes = [];
  final DateTime _fechaSeleccionada = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }
  
  // Método para convertir hora en formato HH:MM a minutos desde medianoche
  int _convertirHoraAMinutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
    });

    try {
      // Cargar áreas comunes del condominio
      final areasSnapshot = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.propietario.condominio)
          .collection('areasComunes')
          .get();

      final areas = areasSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nombre': data['nombre']?.toString() ?? 'Área sin nombre',
          'tipo': data['tipo']?.toString() ?? 'Otro',
          'descripcion': data['descripcion']?.toString() ?? '',
          'horarioInicio': data['horarioInicio']?.toString() ?? '08:00',
          'horarioFin': data['horarioFin']?.toString() ?? '22:00',
          'imagen': data['imagen']?.toString(),
        };
      }).toList();

      // Si no hay áreas comunes, crear algunas por defecto
      if (areas.isEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        
        final areasDefault = [
          {
            'nombre': 'Cancha de Fútbol',
            'tipo': 'cancha',
            'descripcion': 'Cancha de fútbol 5 con césped sintético',
            'horarioInicio': '08:00',
            'horarioFin': '22:00',
            'imagen': 'https://firebasestorage.googleapis.com/v0/b/fortguards.appspot.com/o/areas%2Fcancha.jpg?alt=media',
          },
          {
            'nombre': 'Churrasquera Principal',
            'tipo': 'churrasquera',
            'descripcion': 'Área de parrilla con capacidad para 15 personas',
            'horarioInicio': '10:00',
            'horarioFin': '23:00',
            'imagen': 'https://firebasestorage.googleapis.com/v0/b/fortguards.appspot.com/o/areas%2Fchurrasquera.jpg?alt=media',
          },
          {
            'nombre': 'Salón de Eventos',
            'tipo': 'salon',
            'descripcion': 'Salón para eventos con capacidad para 50 personas',
            'horarioInicio': '09:00',
            'horarioFin': '00:00',
            'imagen': 'https://firebasestorage.googleapis.com/v0/b/fortguards.appspot.com/o/areas%2Fsalon.jpg?alt=media',
          },
        ];
        
        for (final area in areasDefault) {
          final docRef = FirebaseFirestore.instance
              .collection('condominios')
              .doc(widget.propietario.condominio)
              .collection('areasComunes')
              .doc();
          
          batch.set(docRef, {
            ...area,
            'creado': Timestamp.now(),
          });
        }
        
        await batch.commit();
        
        // Cargar nuevamente las áreas
        final areasSnapshotNew = await FirebaseFirestore.instance
            .collection('condominios')
            .doc(widget.propietario.condominio)
            .collection('areasComunes')
            .get();

        final areasNew = areasSnapshotNew.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nombre': data['nombre']?.toString() ?? 'Área sin nombre',
            'tipo': data['tipo']?.toString() ?? 'Otro',
            'descripcion': data['descripcion']?.toString() ?? '',
            'horarioInicio': data['horarioInicio']?.toString() ?? '08:00',
            'horarioFin': data['horarioFin']?.toString() ?? '22:00',
            'imagen': data['imagen']?.toString(),
          };
        }).toList();
        
        setState(() {
          _areasComunes = areasNew;
        });
      } else {
        setState(() {
          _areasComunes = areas;
        });
      }

      // Cargar mis reservas
      await _cargarMisReservas();
    } catch (e) {
      if (mounted) {
        // Verificar si el error es por falta de índice
        if (e.toString().contains('requires an index')) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Se requiere crear un índice en Firestore. Por favor, sigue el enlace en la consola de desarrollo o contacta al administrador.',
              ),
              duration: Duration(seconds: 10),
            ),
          );
        } else {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error al cargar datos: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarMisReservas() async {
    try {
      // Mostrar indicador de carga
      setState(() {
        _cargando = true;
      });
      final reservasSnapshot = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.propietario.condominio)
          .collection('reservas')
          .where('casaNumero', isEqualTo: widget.propietario.casa.numero)
          .orderBy('fecha', descending: true)
          .get();

      final reservas = await Future.wait(reservasSnapshot.docs.map((doc) async {
        final data = doc.data();
        final areaId = data['areaId']?.toString() ?? '';
        
        // Obtener detalles del área
        String nombreArea = 'Área desconocida';
        String tipoArea = 'otro';
        
        if (areaId.isNotEmpty) {
          try {
            final areaDoc = await FirebaseFirestore.instance
                .collection('condominios')
                .doc(widget.propietario.condominio)
                .collection('areasComunes')
                .doc(areaId)
                .get();
                
            if (areaDoc.exists) {
              nombreArea = areaDoc.data()?['nombre']?.toString() ?? nombreArea;
              tipoArea = areaDoc.data()?['tipo']?.toString() ?? tipoArea;
            }
          } catch (e) {
            // Ignorar errores al obtener área
          }
        }
        
        return {
          'id': doc.id,
          'areaId': areaId,
          'nombreArea': nombreArea,
          'tipoArea': tipoArea,
          'fecha': (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'horaInicio': data['horaInicio']?.toString() ?? '00:00',
          'horaFin': data['horaFin']?.toString() ?? '00:00',
          'estado': data['estado']?.toString() ?? 'pendiente',
          'motivo': data['motivo']?.toString() ?? '',
        };
      }));

      // Filtrar reservas obsoletas, canceladas y pasadas
      final reservasFiltradas = _filtrarReservasValidas(reservas);

      setState(() {
        _misReservas = reservasFiltradas;
      });
    } catch (e) {
      if (mounted) {
        // Verificar si el error es por falta de índice
        if (e.toString().contains('requires an index')) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Se requiere crear un índice en Firestore. Por favor, sigue el enlace en la consola de desarrollo o contacta al administrador.',
              ),
              duration: Duration(seconds: 10),
            ),
          );
        } else {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error al cargar reservas: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _nuevaReserva(Map<String, dynamic> area) async {
    if (!mounted) return;
    final formKey = GlobalKey<FormState>();
    final fechaController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
    );
    final horaInicioController = TextEditingController(text: area['horarioInicio']);
    final horaFinController = TextEditingController(text: area['horarioFin']);
    final motivoController = TextEditingController();
    
    DateTime fechaSeleccionada = _fechaSeleccionada;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reservar ${area['nombre']}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (fecha != null) {
                      fechaSeleccionada = fecha;
                      fechaController.text = DateFormat('dd/MM/yyyy').format(fecha);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: fechaController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor seleccione una fecha';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final hora = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.parse(horaInicioController.text.split(':')[0]),
                              minute: int.parse(horaInicioController.text.split(':')[1]),
                            ),
                          );
                          if (hora != null) {
                            horaInicioController.text = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: horaInicioController,
                            decoration: const InputDecoration(
                              labelText: 'Hora inicio',
                              suffixIcon: Icon(Icons.access_time),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requerido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final hora = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.parse(horaFinController.text.split(':')[0]),
                              minute: int.parse(horaFinController.text.split(':')[1]),
                            ),
                          );
                          if (hora != null) {
                            horaFinController.text = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: horaFinController,
                            decoration: const InputDecoration(
                              labelText: 'Hora fin',
                              suffixIcon: Icon(Icons.access_time),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requerido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                    hintText: 'Ej: Cumpleaños, Reunión familiar',
                  ),
                  maxLines: 2,
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
                
                // Capturar ScaffoldMessengerState ANTES de operaciones asíncronas
                final scaffoldMessengerState = ScaffoldMessenger.of(context);
                
                setState(() {
                  _cargando = true;
                });

                try {
                  // Verificar disponibilidad
                  final fechaReserva = DateFormat('dd/MM/yyyy').parse(fechaController.text);
                  
                  final reservasExistentes = await FirebaseFirestore.instance
                      .collection('condominios')
                      .doc(widget.propietario.condominio)
                      .collection('reservas')
                      .where('areaId', isEqualTo: area['id'])
                      .where('fecha', isEqualTo: Timestamp.fromDate(DateTime(
                        fechaReserva.year,
                        fechaReserva.month,
                        fechaReserva.day,
                      )))
                      .get();
                  
                  // Verificar si hay conflicto de horarios
                  bool hayConflicto = false;
                  final horaInicioNueva = horaInicioController.text;
                  final horaFinNueva = horaFinController.text;
                  
                  // Validar que la hora esté dentro del horario del área
                  final horaInicioArea = area['horarioInicio'] as String;
                  final horaFinArea = area['horarioFin'] as String;
                  
                  final horaInicioAreaMinutos = _convertirHoraAMinutos(horaInicioArea);
                  final horaFinAreaMinutos = _convertirHoraAMinutos(horaFinArea);
                  final horaInicioNuevaMinutos = _convertirHoraAMinutos(horaInicioController.text);
                  final horaFinNuevaMinutos = _convertirHoraAMinutos(horaFinController.text);
                  
                  if (horaInicioNuevaMinutos < horaInicioAreaMinutos || 
                      horaFinNuevaMinutos > horaFinAreaMinutos) {
                    if (mounted) {
                      scaffoldMessengerState.showSnackBar(
                        SnackBar(content: Text(
                          'El horario debe estar entre ${area["horarioInicio"]} y ${area["horarioFin"]}'
                        )),
                      );
                    }
                    return;
                  }
                  
                  // Verificar conflictos con reservas existentes
                  for (final doc in reservasExistentes.docs) {
                    
                    // Convertir strings a DateTime para comparación
                    final horaInicioNuevaMinutos = _convertirHoraAMinutos(horaInicioNueva);
                    final horaFinNuevaMinutos = _convertirHoraAMinutos(horaFinNueva);
                    final horaInicioMinutos = _convertirHoraAMinutos(doc.data()['horaInicio']?.toString() ?? '');
                    final horaFinMinutos = _convertirHoraAMinutos(doc.data()['horaFin']?.toString() ?? '');
                    
                    // Verificar si hay solapamiento
                    if ((horaInicioNuevaMinutos >= horaInicioMinutos && horaInicioNuevaMinutos < horaFinMinutos) ||
                        (horaFinNuevaMinutos > horaInicioMinutos && horaFinNuevaMinutos <= horaFinMinutos) ||
                        (horaInicioNuevaMinutos <= horaInicioMinutos && horaFinNuevaMinutos >= horaFinMinutos)) {
                      hayConflicto = true;
                      break;
                    }
                  }
                  
                  if (hayConflicto) {
                    // Capturar ScaffoldMessengerState antes de cualquier operación asíncrona
                    if (mounted) {
                      scaffoldMessengerState.showSnackBar(
                        const SnackBar(content: Text('El horario seleccionado ya está reservado')),
                      );
                    }
                    return;
                  }
                  
                  // Crear la reserva
                  await FirebaseFirestore.instance
                      .collection('condominios')
                      .doc(widget.propietario.condominio)
                      .collection('reservas')
                      .add({
                    'areaId': area['id'],
                    'casaNumero': widget.propietario.casa.numero,
                    'propietario': widget.propietario.casa.nombre,
                    'fecha': Timestamp.fromDate(DateTime(
                      fechaReserva.year,
                      fechaReserva.month,
                      fechaReserva.day,
                    )),
                    'horaInicio': horaInicioController.text,
                    'horaFin': horaFinController.text,
                    'motivo': motivoController.text,
                    'estado': 'confirmada',
                    'creado': Timestamp.now(),
                  });

                  // Recargar mis reservas
                  await _cargarMisReservas();

                  // Mostrar mensaje de éxito
                  if (mounted) {
                    scaffoldMessengerState.showSnackBar(
                      const SnackBar(content: Text('Reserva creada con éxito'))
                    );
                  }

                  // Cambiar a la pestaña de mis reservas
                  _tabController.animateTo(0);
                } catch (e) {
                  if (mounted) {
                    scaffoldMessengerState.showSnackBar(
                      SnackBar(content: Text('Error al crear la reserva: $e'))
                    );
                  }
                } finally {
                  setState(() {
                    _cargando = false;
                  });
                }
              }
            },
            child: const Text('Reservar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarReserva(Map<String, dynamic> reserva) async {
  // Capturar ScaffoldMessengerState ANTES de cualquier operación asíncrona
  // incluyendo el showDialog, para evitar el error "Don't use BuildContext across async gaps"
  final scaffoldMessengerState = ScaffoldMessenger.of(context);
  
  if (!mounted) return;
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancelar Reserva'),
      content: const Text('¿Está seguro que desea cancelar esta reserva?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sí, Cancelar'),
        ),
      ],
    ),
  );

  if (confirmar == true && mounted) {
    setState(() {
      _cargando = true;
    });

      try {
        await FirebaseFirestore.instance
            .collection('condominios')
            .doc(widget.propietario.condominio)
            .collection('reservas')
            .doc(reserva['id'])
            .update({
          'estado': 'cancelada',
        });

        await _cargarMisReservas();

        if (mounted) {
          scaffoldMessengerState.showSnackBar(
            const SnackBar(content: Text('Reserva cancelada')),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessengerState.showSnackBar(
            SnackBar(content: Text('Error al cancelar reserva: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _cargando = false;
          });
        }
      }
    }
  }

  Widget _buildMisReservasTab() {
    if (_misReservas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes reservas',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Ve a la pestaña "Áreas Comunes" para hacer una reserva',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _misReservas.length,
      itemBuilder: (context, index) {
        final reserva = _misReservas[index];
        final fecha = reserva['fecha'] as DateTime;
        final estado = reserva['estado'] as String;
        
        Color colorEstado;
        IconData iconoEstado;
        
        switch (estado) {
          case 'confirmada':
            colorEstado = Colors.green;
            iconoEstado = Icons.check_circle;
            break;
          case 'cancelada':
            colorEstado = Colors.red;
            iconoEstado = Icons.cancel;
            break;
          case 'pendiente':
            colorEstado = Colors.orange;
            iconoEstado = Icons.pending;
            break;
          default:
            colorEstado = Colors.blue;
            iconoEstado = Icons.info;
        }
        
        IconData iconoTipo;
        switch (reserva['tipoArea']) {
          case 'cancha':
            iconoTipo = Icons.sports_soccer;
            break;
          case 'churrasquera':
            iconoTipo = Icons.outdoor_grill;
            break;
          case 'salon':
            iconoTipo = Icons.celebration;
            break;
          default:
            iconoTipo = Icons.location_on;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(iconoTipo, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reserva['nombreArea'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${DateFormat('EEEE dd/MM/yyyy', 'es').format(fecha)} · ${reserva['horaInicio']} - ${reserva['horaFin']}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if ((reserva['motivo'] as String).isNotEmpty) ...[
                  Text(
                    'Motivo: ${reserva['motivo']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorEstado.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoEstado, size: 16, color: colorEstado),
                          const SizedBox(width: 4),
                          Text(
                            estado.toUpperCase(),
                            style: TextStyle(
                              color: colorEstado,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (estado == 'confirmada' && fecha.isAfter(DateTime.now())) 
                      TextButton.icon(
                        onPressed: () => _cancelarReserva(reserva),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
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

  Widget _buildAreasTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _areasComunes.length,
      itemBuilder: (context, index) {
        final area = _areasComunes[index];
        
        IconData iconoTipo;
        switch (area['tipo']) {
          case 'cancha':
            iconoTipo = Icons.sports_soccer;
            break;
          case 'churrasquera':
            iconoTipo = Icons.outdoor_grill;
            break;
          case 'salon':
            iconoTipo = Icons.celebration;
            break;
          default:
            iconoTipo = Icons.location_on;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (area['imagen'] != null) 
                Image.network(
                  area['imagen'],
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(iconoTipo, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                area['nombre'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Horario: ${area['horarioInicio']} - ${area['horarioFin']}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((area['descripcion'] as String).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        area['descripcion'] as String,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _nuevaReserva(area),
                        icon: const Icon(Icons.event_available),
                        label: const Text('Reservar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Reservas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mis Reservas'),
            Tab(text: 'Áreas Comunes'),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMisReservasTab(),
                _buildAreasTab(),
              ],
            ),
      ),
    );
  }

  /// Filtra las reservas para mostrar solo las válidas (no canceladas, no obsoletas)
  List<Map<String, dynamic>> _filtrarReservasValidas(List<Map<String, dynamic>> reservas) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    
    return reservas.where((reserva) {
      final estado = reserva['estado']?.toString().toLowerCase() ?? 'pendiente';
      final fechaReserva = reserva['fecha'] as DateTime;
      final fechaReservaSinHora = DateTime(fechaReserva.year, fechaReserva.month, fechaReserva.day);
      
      // Filtrar reservas canceladas
      if (estado == 'cancelada' || estado == 'rechazada') {
        return false;
      }
      
      // Filtrar reservas de días pasados (excepto las de hoy)
      if (fechaReservaSinHora.isBefore(hoy)) {
        return false;
      }
      
      // Si es hoy, verificar si ya pasó la hora de fin
      if (fechaReservaSinHora.isAtSameMomentAs(hoy)) {
        final horaFin = reserva['horaFin']?.toString() ?? '23:59';
        try {
          final partesHora = horaFin.split(':');
          final horaFinDateTime = DateTime(
            ahora.year,
            ahora.month,
            ahora.day,
            int.parse(partesHora[0]),
            int.parse(partesHora[1]),
          );
          
          // Si ya pasó la hora de fin, no mostrar
          if (ahora.isAfter(horaFinDateTime)) {
            return false;
          }
        } catch (e) {
          // Si hay error parseando la hora, mantener la reserva
        }
      }
      
      return true;
    }).toList();
  }
}
