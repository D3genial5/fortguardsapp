import 'dart:convert';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/back_handler.dart';

import '../../models/propietario_model.dart';
import '../../core/codigo_casa_util.dart';
import '../../services/alerta_service.dart';

import 'package:fortguardsapp/screens/propietario/pago_expensas_screen.dart';
import 'package:fortguardsapp/screens/propietario/gestionar_solicitudes_screen.dart';
import 'package:fortguardsapp/screens/propietario/mis_qrs_invitados_screen.dart';
import 'notificaciones_prop_screen.dart';
import 'reservas_screen.dart';
import '../../theme_manager.dart';

class PanelPropietarioScreen extends StatefulWidget {
  const PanelPropietarioScreen({super.key});

  @override
  State<PanelPropietarioScreen> createState() => _PanelPropietarioScreenState();
}

class _PanelPropietarioScreenState extends State<PanelPropietarioScreen> with SingleTickerProviderStateMixin {
  PropietarioModel? propietario;
  String? estadoExpensa;
  bool botonPeligroActivo = false;
  
  // Información del código
  DateTime? codigoExpira;
  int? codigoUsos;

  final List<String> alertas = [
    'Necesito ayuda en casa',
    'Ambulancia',
    'Incendio',
    'Alerta',
  ];

  StreamSubscription<DocumentSnapshot>? _codigoSubscription;
  StreamSubscription<DocumentSnapshot>? _autoRenovacionSubscription;
  
  // Controladores y animaciones
  late AnimationController _animacionController;
  late Animation<double> _animacionRotacion;
  late Animation<double> _animacionForma;
  bool _mostrandoOpciones = false;
  final double _radiosBorde = 16.0; // Radio de los bordes en estado normal
  
  @override
  void initState() {
    super.initState();
    
    // Inicializar controlador de animación
    _animacionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Rotación muy rápida
    );
    
    // Crear animación de rotación ultra rápida (50 vueltas completas)
    _animacionRotacion = Tween<double>(
      begin: 0.0,
      end: 10000.0 * 3.14159, // 50 vueltas completas (100π radianes) - velocidad extrema
    ).animate(CurvedAnimation(
      parent: _animacionController,
      curve: Curves.linear, // Usar curva lineal para velocidad constante
    ));
    
    // Animación para cambiar de cuadrado a círculo (valor de 0 a 1)
    _animacionForma = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animacionController,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut), // Solo al inicio de la animación
    ));
    
    _cargarDatos();
  }
  
  @override
  void dispose() {
    _animacionController.dispose();
    _codigoSubscription?.cancel();
    _autoRenovacionSubscription?.cancel();
    super.dispose();
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? colorScheme.error : colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? colorScheme.error : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
    );
  }
  
  Widget _buildAccesoRapido({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: Theme.of(context).colorScheme.primary,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icono,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('propietario');

    PropietarioModel? modelo;
    if (jsonString != null) {
      try {
        final jsonMap = jsonDecode(jsonString);
        modelo = PropietarioModel.fromJson(jsonMap);
      } catch (_) {}
    }

    // Fallback: reconstruir desde sesión local si no hay modelo persistido
    if (modelo == null) {
      final condominioId = prefs.getString('condominioId');
      final casaNumero = prefs.getInt('casaNumero');
      if (condominioId != null && casaNumero != null) {
        modelo = PropietarioModel(
          condominio: condominioId,
          casa: Casa(nombre: casaNumero.toString(), numero: casaNumero),
          codigoCasa: '',
          personas: const [],
        );
      }
    }

    if (modelo == null) return;

    if (!mounted) return;
    setState(() {
      propietario = modelo;
    });

    unawaited(_sincronizarDatosConFirestore(modelo));
  }

  Future<void> _sincronizarDatosConFirestore(PropietarioModel base) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(base.condominio)
          .collection('casas')
          .doc(base.casa.numero.toString())
          .get();

      List<String> personas = base.personas;
      String? expensa;
      DateTime? expiracion;
      int? usos;

      if (doc.exists) {
        final data = doc.data()!;
        if (data['residentes'] != null) {
          personas = List<String>.from(data['residentes']);
        }
        expensa = data['estadoExpensa']?.toString();
        if (data['codigoExpira'] != null) {
          expiracion = (data['codigoExpira'] as Timestamp).toDate();
        }
        if (data['codigoUsos'] != null) {
          usos = data['codigoUsos'] as int;
        }
      }

      final identificador = '${base.condominio}_${base.casa.numero}';
      final codigoDinamico = await CodigoCasaUtil.obtenerOCrearCodigo(identificador: identificador);

      await FirebaseFirestore.instance
          .collection('condominios')
          .doc(base.condominio)
          .collection('casas')
          .doc(base.casa.numero.toString())
          .set({'codigoCasa': codigoDinamico}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        propietario = base.copyWith(codigoCasa: codigoDinamico, personas: personas);
        estadoExpensa = expensa;
        codigoExpira = expiracion;
        codigoUsos = usos;
      });

      _escucharCambiosCodigo(base.condominio, base.casa.numero);
      _autoRenovacionSubscription?.cancel();
      _autoRenovacionSubscription = CodigoCasaUtil.iniciarAutoRenovacionCodigo(
        identificador: identificador,
        condominioId: base.condominio,
        casaNumero: base.casa.numero,
      );
    } catch (_) {}
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  void _mostrarDialogoConfiguracion() {
    int duracionHoras = 24; // Por defecto 24 horas (1 día)
    int usos = 1; // Por defecto 1 uso
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título con icono
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.settings,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Configurar código de casa',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Duración del código
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Duración del código:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                        ),
                        child: Slider(
                          value: duracionHoras.toDouble(),
                          min: 1,
                          max: 24,
                          divisions: 23,
                          label: '$duracionHoras ${duracionHoras == 1 ? "hora" : "horas"}',
                          onChanged: (value) {
                            setStateDialog(() {
                              duracionHoras = value.round();
                            });
                          },
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$duracionHoras ${duracionHoras == 1 ? "hora" : "horas"}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Cantidad de usos
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.numbers,
                            size: 20,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cantidad de usos:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                        ),
                        child: Slider(
                          value: usos.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$usos ${usos == 1 ? "uso" : "usos"}',
                          onChanged: (value) {
                            setStateDialog(() {
                              usos = value.round();
                            });
                          },
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$usos ${usos == 1 ? "uso" : "usos"}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _generarNuevoCodigo(duracionHoras: duracionHoras, usos: usos);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text(
                        'Generar',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  
  void _escucharCambiosCodigo(String condominioId, int casaNumero) {
    // Cancelar suscripción anterior si existe
    _codigoSubscription?.cancel();
    
    // Crear nueva suscripción con actualización en tiempo real
    _codigoSubscription = FirebaseFirestore.instance
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(casaNumero.toString())
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists || !mounted) return;
          
          final data = snapshot.data()!;
          final nuevoCodigo = data['codigoCasa']?.toString();
          final expira = data['codigoExpira'] as Timestamp?;
          final usos = data['codigoUsos'] as int?;
          
          // Siempre actualizar si hay un código válido
          if (nuevoCodigo != null && propietario != null) {
            // Verificar si el código realmente cambió
            final codigoActual = propietario!.codigoCasa;
            final codigoCambio = codigoActual != nuevoCodigo;
            final usosCambiaron = codigoUsos != usos;
            
            if (codigoCambio || usosCambiaron) {
              // Actualizar SharedPreferences para mantener sincronía
              final prefs = await SharedPreferences.getInstance();
              final identificador = '${propietario!.condominio}_${propietario!.casa.numero}';
              await prefs.setString('codigo_$identificador', nuevoCodigo);
              
              // Actualizar modelo en memoria
              final nuevoModelo = propietario!.copyWith(codigoCasa: nuevoCodigo);
              final jsonString = jsonEncode(nuevoModelo.toJson());
              await prefs.setString('propietario', jsonString);
              
              if (!mounted) return;
              setState(() {
                propietario = nuevoModelo;
                if (expira != null) codigoExpira = expira.toDate();
                if (usos != null) codigoUsos = usos;
              });
            }
          }
        }, onError: (error) {
          // Reconectar en caso de error
          debugPrint('Error en listener de código: $error');
        });
  }

  Future<void> _generarNuevoCodigo({required int duracionHoras, required int usos}) async {
    if (propietario == null) return;
    
    final identificador = '${propietario!.condominio}_${propietario!.casa.numero}';
    final duracion = Duration(hours: duracionHoras);
    
    try {
      final resultado = await CodigoCasaUtil.generarNuevoCodigo(
        identificador: identificador,
        condominioId: propietario!.condominio,
        casaNumero: propietario!.casa.numero,
        duracion: duracion,
        usos: usos,
      );
      
      if (!mounted) return;
      setState(() {
        propietario = propietario!.copyWith(codigoCasa: resultado['codigo']);
        codigoExpira = resultado['expira'] as DateTime;
        codigoUsos = resultado['usosDisponibles'] as int;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código generado exitosamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar código: $e')),
      );
    }
  }

  Future<void> _mostrarAlertaSeleccionada(String opcion) async {
    if (propietario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontraron datos del propietario')),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Confirmar Alerta'),
          ],
        ),
        content: Text('¿Estás seguro de enviar una alerta de "$opcion"?\n\nEsto notificará al guardia de turno inmediatamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Enviar Alerta'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Enviar alerta a Firebase
      await AlertaService.enviarAlerta(
        tipo: AlertaService.tipoAlertaToFirebase(opcion),
        casaNumero: propietario!.casa.numero,
        condominio: propietario!.condominio,
        propietarioId: '${propietario!.condominio}_${propietario!.casa.numero}',
        propietarioNombre: propietario!.personas.isNotEmpty 
            ? propietario!.personas.first 
            : 'Propietario',
      );

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Alerta enviada. El guardia será notificado.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _mostrarOpcionesAlertas() {
  // Usar ModalBottomSheet en lugar de Dialog para evitar el problema de visualización
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true, // Permitir que ocupe el espacio necesario
    isDismissible: true, // Asegurar que se pueda cerrar tocando fuera
    enableDrag: true, // Permitir cerrar deslizando
    builder: (context) => Stack(
      children: [
        // Área transparente clickeable para cerrar
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Modal con opciones
        Padding(
          padding: const EdgeInsets.only(bottom: 80), // Espacio para el FAB
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack, // Efecto de rebote al final
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    alignment: Alignment.bottomRight, // Inflar desde abajo a la derecha
                    child: Container(
                      width: 250,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black54
                                : Colors.black26,
                            blurRadius: 15,
                            spreadRadius: 3,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botón explícito para cerrar
                          Align(
                            alignment: Alignment.topRight,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                                child: Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                              ),
                            ),
                          ),
                          // Opciones de alerta
                          ...alertas.map((alerta) {
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  Navigator.pop(context);
                                  _mostrarAlertaSeleccionada(alerta);
                                },
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.warning_amber, color: Colors.red, size: 28),
                                  title: Text(
                                    alerta, 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (propietario == null) {
      return BackHandler(
        onBackPressed: () {
          context.go('/acceso-general');
        },
        child: Scaffold(
        body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return BackHandler(
      onBackPressed: () {
        context.go('/acceso-general');
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('PROPIETARIO'),
      ),
      drawer: Drawer(
        elevation: 8.0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        )),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.home_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Casa ${propietario!.casa.numero}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MENÚ PRINCIPAL',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildDrawerItem(
                    icon: Icons.notifications,
                    title: 'Notificaciones privadas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NotificacionesPropScreen(propietario: propietario!, initialIndex: 0),
                      ));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.campaign,
                    title: 'Notificaciones del condominio',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NotificacionesPropScreen(propietario: propietario!, initialIndex: 1),
                      ));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'Reservas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReservasScreen(propietario: propietario!),
                      ));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payment,
                    title: 'Pago expensas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PagoExpensasScreen(propietario: propietario!),
                      ));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Invitados',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GestionarSolicitudesScreen(
                          propietario: propietario!,
                        ),
                      ));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.qr_code_2,
                    title: 'Crear QRs',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MisQrsInvitadosScreen(
                          propietario: propietario!,
                        ),
                      ));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.help_center, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Centro de ayuda'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/help');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Acerca de nosotros'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/about');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Términos y condiciones'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/terms');
                    },
                  ),
                  SwitchListTile(
                    secondary: Icon(Icons.brightness_6, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Tema oscuro'),
                    value: ThemeManager.notifier.value == ThemeMode.dark,
                    onChanged: (_) {
                      ThemeManager.toggle();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: _buildDrawerItem(
                icon: Icons.logout,
                title: 'Cerrar sesión',
                onTap: () async {
                  // Capturar router antes de operaciones async
                  final router = GoRouter.of(context);
                  final prefs = await SharedPreferences.getInstance();
                  // Limpiar TODOS los datos de sesión
                  await prefs.remove('propietario');
                  await prefs.remove('userId');
                  if (!mounted) return;
                  // Redirigir a acceso general
                  router.go('/acceso-general');
                },
                isDestructive: true,
              ),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Sección del código de la casa mejorada
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CÓDIGO DE LA CASA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Código con diseño mejorado
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: propietario!.codigoCasa
                              .split('')
                              .map((digit) => Material(
                                    elevation: 6,
                                    borderRadius: BorderRadius.circular(12),
                                    color: Theme.of(context).colorScheme.primary,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Text(
                                        digit,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Información del código
                    if (codigoExpira != null || codigoUsos != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            if (codigoExpira != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Expira: ${_formatearFecha(codigoExpira!)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            if (codigoExpira != null && codigoUsos != null)
                              const SizedBox(height: 4),
                            if (codigoUsos != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.numbers,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Usos restantes: $codigoUsos',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Botón mejorado
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.settings_rounded, color: Colors.black),
                        label: const Text(
                          'Configurar Código',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () => _mostrarDialogoConfiguracion(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Accesos rápidos
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dashboard_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Accesos Rápidos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: _buildAccesoRapido(
                              icono: Icons.event_available_rounded,
                              texto: 'Reservas',
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ReservasScreen(propietario: propietario!),
                                ));
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildAccesoRapido(
                              icono: Icons.payment_rounded,
                              texto: 'Expensas',
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => PagoExpensasScreen(propietario: propietario!),
                                ));
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildAccesoRapido(
                              icono: Icons.notifications_rounded,
                              texto: 'Notificaciones',
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => NotificacionesPropScreen(propietario: propietario!, initialIndex: 0),
                                ));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Información de la casa mejorada
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con icono
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Casa ${propietario!.casa.numero}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Condominio: ${propietario!.condominio}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Personas registradas
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Personas registradas:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...propietario!.personas.map((nombre) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  nombre,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Estado de expensas
                    if (estadoExpensa != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: estadoExpensa == 'Pagado' 
                              ? Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              estadoExpensa == 'Pagado' ? Icons.check_circle_rounded : Icons.warning_rounded,
                              color: estadoExpensa == 'Pagado' 
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Estado expensa:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: estadoExpensa == 'Pagado' 
                                    ? Theme.of(context).colorScheme.onTertiaryContainer
                                    : Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: estadoExpensa == 'Pagado' 
                                    ? Theme.of(context).colorScheme.tertiary
                                    : Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                estadoExpensa!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: estadoExpensa == 'Pagado' 
                                      ? Theme.of(context).colorScheme.onTertiary
                                      : Theme.of(context).colorScheme.onError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Sección de invitados aceptados mejorada
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.people_alt_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Invitados Aceptados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('access_requests')
                            .where('condominio', isEqualTo: propietario!.condominio)
                            .where('casaNumero', isEqualTo: propietario!.casa.numero)
                            .where('estado', isEqualTo: 'aceptada')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Text('No hay invitados aceptados');
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final nombre = data['nombre'] ?? '';
                              final ci = data['ci'] ?? '';
                              final usos = data['codigoUsos'] ?? 1;
                              return ListTile(
                                title: Text(nombre),
                                subtitle: Text('CI: $ci | Usos: $usos'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        // Confirmar eliminación
                                        final dialogContext = context;
                                        // Capturar antes del await
                                        final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                                        final confirmar = await showDialog<bool>(
                                          context: dialogContext,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Eliminar invitado'),
                                            content: Text('¿Estás seguro de eliminar a $nombre?\n\nEsta acción no se puede deshacer.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirmar == true) {
                                          try {
                                            await docs[index].reference.delete();
                                            if (!mounted) return;
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(content: Text('$nombre ha sido eliminado')),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            scaffoldMessenger.showSnackBar(
                                              const SnackBar(content: Text('Error al eliminar el invitado')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        // Capturar antes del await
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        final resultado = await showDialog<Map<String, dynamic>>(
                                          context: context,
                                          builder: (ctx) => _buildModificarAccesoDialog(nombre, usos, data),
                                        );
                                        
                                        if (resultado != null) {
                                          try {
                                            await docs[index].reference.update(resultado);
                                            if (!mounted) return;
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(content: Text('Acceso de $nombre actualizado')),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                content: Text('Error al actualizar: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _animacionController,
        builder: (context, child) {
          // Efecto de rotación muy rápida
          return Transform.rotate(
            angle: _animacionRotacion.value,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              elevation: 8,
              // Usamos RoundedRectangleBorder para controlar los bordes con precisión
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_mostrandoOpciones ? (_animacionForma.value * 40.0) : _radiosBorde),
              ),
              child: _mostrandoOpciones
                  // Efecto de dona negra dentro del botón rojo durante la rotación
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // Círculo negro (dona) - tamaño levemente mayor cuando está completamente circular
                        Container(
                          width: 30 + (_animacionForma.value * 2),
                          height: 30 + (_animacionForma.value * 2),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            // Forma animada: de cuadrado a circular para el anillo negro
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Agujero central (se ve el fondo rojo)
                        Container(
                          // El agujero crece levemente con la animación
                          width: 8 + (_animacionForma.value * 4),
                          height: 8 + (_animacionForma.value * 4),
                          decoration: const BoxDecoration(
                            color: Colors.red, // Color del botón (rojo)
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    )
                  // Icono normal cuando no está girando
                  : Icon(
                  Icons.warning,
                  size: 28,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              onPressed: () {
                if (_mostrandoOpciones) {
                  // Si ya está mostrando opciones, ocultar
                  setState(() {
                    _mostrandoOpciones = false;
                  });
                  // Cerrar diálogo si está abierto
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                } else {
                  // Comenzar la animación de rotación ultra rápida
                  setState(() {
                    _mostrandoOpciones = true;
                  });
                  
                  _animacionController.reset();
                  _animacionController.forward().then((_) {
                    if (!mounted) return;
                    
                    // Mostrar opciones como burbuja inflándose desde el botón
                    _mostrarOpcionesAlertas();
                    
                    setState(() {
                      _mostrandoOpciones = false;
                    });
                  });
                }
              },
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildModificarAccesoDialog(String nombre, int usosActuales, Map<String, dynamic> data) {
    // Detectar el tipo de acceso actual basado en los datos existentes
    String tipoAcceso = data['tipoAcceso'] ?? 'usos';
    
    // Si el tipo no está definido pero los usos son muy altos, probablemente es indefinido
    if (tipoAcceso == 'usos' && usosActuales > 50) {
      if (data['fechaExpiracion'] != null) {
        tipoAcceso = 'tiempo';
      } else {
        tipoAcceso = 'indefinido';
      }
    }
    
    // Configurar valores iniciales seguros
    int usos = (usosActuales > 50) ? 5 : usosActuales; // Valor seguro para el slider
    int duracionValor = data['duracionValor'] ?? 1;
    String duracionUnidad = data['duracionUnidad'] ?? 'meses';
    
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
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modificar acceso',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            nombre,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Tipo de acceso
                Text(
                  'Tipo de acceso:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Opciones de tipo
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTipoAccesoTile(
                        context,
                        'usos',
                        Icons.repeat,
                        'Por número de usos',
                        'Limitar la cantidad de veces que puede usar el código',
                        tipoAcceso,
                        (valor) => setStateDialog(() => tipoAcceso = valor),
                      ),
                      Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                      _buildTipoAccesoTile(
                        context,
                        'tiempo',
                        Icons.schedule,
                        'Por tiempo limitado',
                        'El código expira después de un período específico',
                        tipoAcceso,
                        (valor) => setStateDialog(() => tipoAcceso = valor),
                      ),
                      Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                      _buildTipoAccesoTile(
                        context,
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
                if (tipoAcceso == 'usos') ..._buildConfiguracionUsos(context, usos, (valor) => setStateDialog(() => usos = valor)),
                if (tipoAcceso == 'tiempo') ..._buildConfiguracionTiempo(context, duracionValor, duracionUnidad, 
                  (valor) => setStateDialog(() => duracionValor = valor),
                  (unidad) => setStateDialog(() => duracionUnidad = unidad),
                ),
                if (tipoAcceso == 'indefinido') ..._buildConfiguracionIndefinido(context),
                
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
                          Map<String, dynamic> resultado = {};
                          
                          switch (tipoAcceso) {
                            case 'usos':
                              resultado = {
                                'codigoUsos': usos,
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
                                'codigoUsos': 999999, // Usos ilimitados durante el tiempo
                                'tipoAcceso': 'tiempo',
                                'fechaExpiracion': expiracion.toIso8601String(),
                                'duracionValor': duracionValor,
                                'duracionUnidad': duracionUnidad,
                              };
                              break;
                            case 'indefinido':
                              resultado = {
                                'codigoUsos': 999999,
                                'tipoAcceso': 'indefinido',
                                'fechaExpiracion': null,
                              };
                              break;
                          }
                          
                          Navigator.pop(context, resultado);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Guardar'),
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

  Widget _buildTipoAccesoTile(
    BuildContext context,
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
                  color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icono,
                  size: 20,
                  color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
                        color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConfiguracionUsos(BuildContext context, int usos, Function(int) onChanged) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cantidad de usos:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: usos.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$usos ${usos == 1 ? "uso" : "usos"}',
              onChanged: (value) => onChanged(value.round()),
            ),
            Center(
              child: Text(
                '$usos ${usos == 1 ? "uso" : "usos"}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConfiguracionTiempo(BuildContext context, int valor, String unidad, Function(int) onValorChanged, Function(String) onUnidadChanged) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duración del acceso:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
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
                        onChanged: (value) => onValorChanged(value.round()),
                      ),
                      Text(
                        '$valor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
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
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
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
                            // Ajustar el valor si es necesario
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
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Expira en $valor $unidad',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConfiguracionIndefinido(BuildContext context) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.all_inclusive,
              color: Theme.of(context).colorScheme.tertiary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso sin restricciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Este invitado podrá usar el código las veces que necesite, sin límite de tiempo. Ideal para familiares cercanos.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
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
