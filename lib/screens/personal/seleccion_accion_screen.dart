import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/back_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeleccionAccionScreen extends StatefulWidget {
  const SeleccionAccionScreen({super.key});

  @override
  State<SeleccionAccionScreen> createState() => _SeleccionAccionScreenState();
}

class _SeleccionAccionScreenState extends State<SeleccionAccionScreen> 
    with WidgetsBindingObserver {
  bool _tieneIngresoActivo = false;
  bool _tieneQrPendiente = false;
  String? _casa;
  String? _condominio;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarIngresoActivo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarIngresoActivo();
    }
  }

  // Se llama cuando la pantalla vuelve a ser visible (navegación)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refrescar estado cada vez que la pantalla está visible
    _verificarIngresoActivo();
  }

  Future<void> _verificarIngresoActivo() async {
    final prefs = await SharedPreferences.getInstance();
    final casa = prefs.getString('casa');
    final condominio = prefs.getString('condominio');
    final tieneIngreso = prefs.getBool('ingreso_activo') ?? false;
    final tieneQrPendiente = prefs.getBool('qr_pendiente') ?? false;
    
    if (mounted) {
      setState(() {
        _casa = casa;
        _condominio = condominio;
        _tieneIngresoActivo = tieneIngreso && casa != null && condominio != null;
        _tieneQrPendiente = tieneQrPendiente && casa != null && condominio != null;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return BackHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visita'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                context.go('/acceso-general');
              }
            },
          ),
        ),
        body: _cargando 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Card de Entrada
                  _buildOptionCard(
                    context,
                    icon: Icons.login_rounded,
                    title: 'Entrada',
                    subtitle: _tieneQrPendiente && !_tieneIngresoActivo
                      ? 'QR generado para $_casa'
                      : _tieneIngresoActivo 
                        ? 'Ya tienes un ingreso activo'
                        : 'Ingresar con código de casa',
                    color: scheme.primary,
                    enabled: !_tieneIngresoActivo,
                    showQrBadge: _tieneQrPendiente && !_tieneIngresoActivo,
                    onTap: () {
                      if (_tieneQrPendiente && !_tieneIngresoActivo && _casa != null && _condominio != null) {
                        // Ya tiene QR, ir directo a mostrarlo
                        context.push('/qr-casa', extra: {
                          'casa': _casa!,
                          'condominio': _condominio!,
                          'esSalida': false,
                          'forzarCodigoCasa': true,
                        });
                      } else {
                        context.push('/seleccion-condominio');
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Card de Salida
                  _buildOptionCard(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Salida',
                    subtitle: _tieneIngresoActivo
                      ? 'Mostrar QR para salir'
                      : 'Primero debes registrar una entrada',
                    color: _tieneIngresoActivo ? Colors.orange : scheme.outline,
                    enabled: _tieneIngresoActivo,
                    onTap: () async {
                      if (_tieneIngresoActivo && _casa != null && _condominio != null) {
                        context.push('/qr-casa', extra: {
                          'casa': _casa!,
                          'condominio': _condominio!,
                          'esSalida': true,
                          'forzarCodigoCasa': true,
                        });
                      }
                    },
                  ),

                  if (_tieneIngresoActivo) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ingreso activo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  '$_casa - $_condominio',
                                  style: TextStyle(
                                    color: scheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool showQrBadge = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Card(
        elevation: enabled ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: enabled ? color.withValues(alpha: 0.3) : scheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Primero debes registrar una entrada'),
                backgroundColor: scheme.error,
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    if (showQrBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled ? color : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
