import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/back_handler.dart';

import '../../models/propietario_model.dart';
import '../../core/codigo_casa_util.dart';
import '../../services/alerta_service.dart';
import '../../services/notificacion_service.dart';

import 'package:fortguardsapp/screens/propietario/pago_expensas_screen.dart';
import 'package:fortguardsapp/screens/propietario/gestionar_solicitudes_screen.dart';
import 'package:fortguardsapp/screens/propietario/mis_qrs_invitados_screen.dart';
import 'notificaciones_prop_screen.dart';
import 'reservas_screen.dart';
import 'panel_widgets.dart';

class PanelPropietarioScreen extends StatefulWidget {
  const PanelPropietarioScreen({super.key});

  @override
  State<PanelPropietarioScreen> createState() => _PanelPropietarioScreenState();
}

class _PanelPropietarioScreenState extends State<PanelPropietarioScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  PropietarioModel? propietario;
  String? estadoExpensa;
  bool _expensasHabilitadas = true;
  bool botonPeligroActivo = false;
  
  // Información del código
  DateTime? codigoExpira;
  int? codigoUsos;
  bool _codigoSincronizando = true;

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

  bool _esExpensaPagada(String? estado) {
    if (estado == null) return false;
    final normalized = estado.toLowerCase();
    return normalized.contains('pagad');
  }
  
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
    NotificacionService.detenerEscucha();
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
      // Compat: versiones anteriores guardaban casaNumero como int.
      final casaNumero = prefs.get('casaNumero')?.toString();
      if (condominioId != null && casaNumero != null) {
        modelo = PropietarioModel(
          condominio: condominioId,
          casa: Casa(nombre: casaNumero, numero: casaNumero),
          codigoCasa: '',
          personas: const [],
        );
      }
    }

    if (modelo == null) return;

    if (!mounted) return;
    setState(() {
      propietario = modelo;
      _codigoSincronizando = true;
    });
    
    // Suscribirse a tópicos FCM para recibir push notifications
    NotificacionService.suscribirseATopicos(
      condominio: modelo.condominio,
      casaNumero: modelo.casa.numero,
    );
    
    // Iniciar escucha de notificaciones push en tiempo real (backup local)
    NotificacionService.escucharNotificaciones(
      condominioId: modelo.condominio,
      casaNumero: modelo.casa.numero,
    );

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
      String? codigoFirestore;

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
        codigoFirestore = data['codigoCasa']?.toString();
      }

      // Leer flag de expensas habilitadas del documento del condominio
      final condominioDoc = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(base.condominio)
          .get();
      final expensasFlag = condominioDoc.data()?['expensasHabilitadas'] ?? true;

      final identificador = '${base.condominio}_${base.casa.numero}';

      // ──────────────────────────────────────────────────────────────────
      // FIRESTORE ES SOURCE OF TRUTH PARA codigoCasa
      // ──────────────────────────────────────────────────────────────────
      // Si Firestore ya tiene un código vigente (no expirado y con usos>0),
      // usamos ESE. Si no, generamos uno nuevo localmente y lo persistimos.
      // Esto evita que el código cambie cuando el propietario re-entra al
      // panel mientras el visitante todavía no agotó el código.
      final ahora = DateTime.now();
      final firestoreCodeValid = codigoFirestore != null
          && codigoFirestore.isNotEmpty
          && (expiracion == null || expiracion.isAfter(ahora))
          && (usos == null || usos > 0);

      String codigoDinamico;
      if (firestoreCodeValid) {
        codigoDinamico = codigoFirestore;
        // Sincronizamos también el secure storage local para que matches
        try {
          await CodigoCasaUtil.guardarCodigoLocal(identificador, codigoDinamico);
        } catch (_) {/* no bloquea */}
      } else {
        // No hay código vigente en Firestore: generamos uno nuevo
        codigoDinamico = await CodigoCasaUtil.obtenerOCrearCodigo(identificador: identificador);
      }

      // 1) UI primero: aseguramos que el código se vea aunque
      //    Firestore después falle por red/regla.
      if (!mounted) return;
      setState(() {
        propietario = base.copyWith(codigoCasa: codigoDinamico, personas: personas);
        estadoExpensa = expensa;
        _expensasHabilitadas = expensasFlag;
        codigoExpira = expiracion;
        codigoUsos = usos;
      });

      // 2) Persistencia remota SOLO si generamos nuevo código.
      //    Si vino de Firestore, ya está ahí — no escribimos para no
      //    triggear listeners ni resetear usos.
      if (!firestoreCodeValid) {
        try {
          await FirebaseFirestore.instance
              .collection('condominios')
              .doc(base.condominio)
              .collection('casas')
              .doc(base.casa.numero.toString())
              .set({'codigoCasa': codigoDinamico}, SetOptions(merge: true));
        } on FirebaseException catch (e) {
          if (kDebugMode) {
            debugPrint('Persistencia codigoCasa falló (no bloquea UI): ${e.code} ${e.message}');
          }
        }
      }

      _escucharCambiosCodigo(base.condominio, base.casa.numero);
      _autoRenovacionSubscription?.cancel();
      _autoRenovacionSubscription = CodigoCasaUtil.iniciarAutoRenovacionCodigo(
        identificador: identificador,
        condominioId: base.condominio,
        casaNumero: base.casa.numero,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error sincronizando código de casa: $e');
    } finally {
      if (mounted) {
        setState(() {
          _codigoSincronizando = false;
        });
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  void _mostrarDialogoConfiguracion() {
    int duracionHoras = 24;
    int usos = 1;
    final usosController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final scheme = Theme.of(context).colorScheme;
          final screenSize = MediaQuery.of(context).size;
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 16,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: screenSize.height * 0.9,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface,
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header con icono animado
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.qr_code_rounded,
                          color: scheme.onPrimary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Generar Código de Acceso',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configura la duración y cantidad de usos permitidos',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      
                      // Duración del código - Diseño mejorado
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.timer_outlined,
                                    size: 22,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Duración',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$duracionHoras ${duracionHoras == 1 ? "hora" : "horas"}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Opciones rápidas de duración
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [1, 6, 12, 24, 48, 72].map((horas) {
                                final selected = duracionHoras == horas;
                                String label = horas < 24 
                                    ? '${horas}h' 
                                    : '${horas ~/ 24}d';
                                return GestureDetector(
                                  onTap: () => setStateDialog(() => duracionHoras = horas),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selected 
                                          ? scheme.primary 
                                          : scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected 
                                            ? scheme.primary 
                                            : scheme.outline.withValues(alpha: 0.3),
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: selected ? scheme.onPrimary : scheme.onSurface,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Cantidad de usos - Con entrada manual
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.repeat_rounded,
                                    size: 22,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Cantidad de Usos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Input manual de usos - Diseño mejorado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Botón decrementar
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: usos > 1 ? () {
                                        setStateDialog(() {
                                          usos--;
                                          usosController.text = usos.toString();
                                        });
                                      } : null,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: usos > 1 
                                            ? Colors.orange.withValues(alpha: 0.2)
                                            : scheme.outline.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.remove_rounded,
                                          color: usos > 1 ? Colors.orange : scheme.outline,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Campo de texto central
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: TextField(
                                        controller: usosController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (value) {
                                          final parsed = int.tryParse(value);
                                          if (parsed != null && parsed >= 1 && parsed <= 50) {
                                            setStateDialog(() => usos = parsed);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  // Botón incrementar
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: usos < 50 ? () {
                                        setStateDialog(() {
                                          usos++;
                                          usosController.text = usos.toString();
                                        });
                                      } : null,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: usos < 50 
                                            ? Colors.orange.withValues(alpha: 0.2)
                                            : scheme.outline.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: usos < 50 ? Colors.orange : scheme.outline,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Opciones rápidas de usos
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [1, 5, 10, 20, 30, 50].map((cantidad) {
                                final selected = usos == cantidad;
                                return GestureDetector(
                                  onTap: () {
                                    setStateDialog(() {
                                      usos = cantidad;
                                      usosController.text = cantidad.toString();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected 
                                          ? Colors.orange 
                                          : scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected 
                                            ? Colors.orange 
                                            : scheme.outline.withValues(alpha: 0.3),
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$cantidad',
                                      style: TextStyle(
                                        color: selected ? Colors.white : scheme.onSurface,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // Botones de acción
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final usarColumna = constraints.maxWidth < 380;

                          final botonCancelar = OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Cancelar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          );

                          final botonGenerar = FilledButton.icon(
                            onPressed: () {
                              // Validar que usos esté en rango
                              final usosFinales = usos.clamp(1, 50);
                              Navigator.pop(context);
                              _generarNuevoCodigo(duracionHoras: duracionHoras, usos: usosFinales);
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                            label: const Text(
                              'Generar Código',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          );

                          if (usarColumna) {
                            return Column(
                              children: [
                                SizedBox(width: double.infinity, child: botonCancelar),
                                const SizedBox(height: 10),
                                SizedBox(width: double.infinity, child: botonGenerar),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: botonCancelar),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: botonGenerar),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _escucharCambiosCodigo(String condominioId, String casaNumero) {
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
          if (kDebugMode) debugPrint('Error en listener de código: $error');
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
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return BackHandler(
      onBackPressed: () {
        // Si el drawer está abierto, cerrarlo en lugar de navegar
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        // Volver al panel de accesos SIN cerrar sesión.
        // El logout lo hace el botón "Cerrar sesión" del drawer.
        context.go('/acceso-general');
      },
      child: Scaffold(
      key: _scaffoldKey,
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
                  if (_expensasHabilitadas)
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
                    title: 'QRs de invitados',
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
                    if (_codigoSincronizando)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Actualizando código...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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
                    if (!_codigoSincronizando && (codigoExpira != null || codigoUsos != null))
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
                          if (_expensasHabilitadas)
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
                              Flexible(
                                child: Text(
                                  'Personas registradas:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
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
                                Flexible(
                                  child: Text(
                                    nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
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
                    if (_expensasHabilitadas && estadoExpensa != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _esExpensaPagada(estadoExpensa)
                              ? Colors.green.withValues(alpha: 0.12)
                              : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _esExpensaPagada(estadoExpensa) ? Icons.check_circle_rounded : Icons.warning_rounded,
                              color: _esExpensaPagada(estadoExpensa)
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Estado expensa:',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: _esExpensaPagada(estadoExpensa)
                                      ? Colors.green.shade800
                                      : Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _esExpensaPagada(estadoExpensa)
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                estadoExpensa!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _esExpensaPagada(estadoExpensa)
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!_expensasHabilitadas)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.money_off_rounded, size: 20, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Expensas inhabilitadas',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
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
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GestionarSolicitudesScreen(propietario: propietario!),
                              ),
                            );
                          },
                          child: Container(
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Invitados Aceptados',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
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
                              final usos = data['usosRestantes'] ?? data['codigoUsos'] ?? 1;
                              final codigoQr = data['codigoQr'] as String?;
                              final tipoAcceso = data['tipoAcceso'] ?? 'usos';
                              final bool esExpirado = tipoAcceso == 'usos' && (usos is int) && usos <= 0;
                              return ListTile(
                                title: Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'CI: $ci | Usos: $usos',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (esExpirado)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.red.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          'Expirado',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    if (!esExpirado && codigoQr != null && codigoQr.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.blue.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          'QR creado',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
                                      icon: Icon(
                                        Icons.edit,
                                        color: esExpirado ? Colors.grey : null,
                                      ),
                                      onPressed: esExpirado ? null : () async {
                                        // Capturar antes del await
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        final actualizado = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => ModificarAccesoDialog(
                                            nombre: nombre,
                                            usosActuales: usos is int ? usos : 1,
                                            data: data,
                                            condominio: propietario!.condominio,
                                            casaNumero: propietario!.casa.numero,
                                            codigoCasa: propietario!.codigoCasa,
                                          ),
                                        );

                                        if (actualizado == true) {
                                          if (!mounted) return;
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(content: Text('Acceso de $nombre actualizado')),
                                          );
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

  // _buildModificarAccesoDialog, _buildTipoAccesoTile, _buildConfiguracionUsos,
  // _buildConfiguracionTiempo, _buildConfiguracionIndefinido
  // fueron extraídos a panel_widgets.dart (ModificarAccesoDialog)
}
