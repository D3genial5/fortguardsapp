import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/back_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import '../../models/propietario_model.dart';
import '../../services/propietario_auth_service.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
// import '../../services/push_notification_service.dart';  // Temporarily disabled
// import '../../services/background_sync_service.dart';  // Temporarily disabled

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _condominioController = TextEditingController();
  final _casaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sessionService = SessionService();
  final _notificationService = NotificationService();
  bool _verificandoSesion = true;
  bool _isLoggingIn = false;
  late final AnimationController _loadingController;
  
  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _condominioController.dispose();
    _casaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildWaveDot(int index) {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        final phase = (_loadingController.value * 2 * math.pi) + (index * 0.8);
        final y = math.sin(phase) * 5;
        final opacity = 0.45 + ((math.sin(phase) + 1) / 2) * 0.55;

        return Transform.translate(
          offset: Offset(0, -y),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
  
  Future<void> _checkExistingSession() async {
    // Verificar si ya hay una sesión activa
    final sessionActive = await _sessionService.isSessionActive();
    if (sessionActive && mounted) {
      context.go('/propietario');
    } else if (mounted) {
      setState(() {
        _verificandoSesion = false;
      });
    }
  }

  void _login() async {
    if (_isLoggingIn) return;

    final condominio = _condominioController.text.trim();
    final casa = _casaController.text.trim();
    final password = _passwordController.text.trim();

    if (condominio.isEmpty || casa.isEmpty || password.isEmpty) {
      _mostrarError('Completa todos los campos');
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    // Mostrar cargando
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final data = await PropietarioAuthService.loginPropietario(
        condominioId: condominio,
        casaId: casa,
        password: password,
      );

      if (mounted) Navigator.of(context).pop();

      if (data != null) {
      // Verificar si es primera vez en este dispositivo
      final isFirstTime = await _sessionService.isFirstTimeOnDevice();
      
      // Crear o actualizar sesión
      final casaData = data['casa'] as Map<String, dynamic>?;
      final casaNumeroRaw = casaData?['numero'];
      final casaNumero = casaNumeroRaw is int
          ? casaNumeroRaw
          : int.tryParse(casaNumeroRaw?.toString() ?? '');
      if (casaNumero == null) {
        throw Exception('No se pudo obtener el número de casa');
      }
      final condominioId = data['condominio'] as String;
      
      // ID derivado de condominio+casa (sin colección credenciales)
      final userId = '${condominioId}_$casaNumero';

      // Crear sesión
      await _sessionService.createOrUpdateSession(
        userId: userId,
        condominioId: condominioId,
        casaNumero: casaNumero,
      );
      
      // Guardar datos en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(
        data,
        toEncodable: (dynamic nonEncodable) {
          if (nonEncodable is Timestamp) {
            return nonEncodable.toDate().toIso8601String();
          }
          return nonEncodable.toString();
        },
      );
      await prefs.setString('propietario', jsonString);
      await prefs.setString('userId', userId);
      
      // Si es primera vez, marcar como completo
      if (isFirstTime) {
        await _sessionService.markDataComplete();
      }
      
      // Inicializar notificaciones en segundo plano (no bloqueante)
      if (mounted) {
        _notificationService.initialize(userId, condominioId: condominioId, casaNumero: casaNumero).then((_) {
          _notificationService.subscribeToCondominio(condominioId);
        }).catchError((e) {
          if (kDebugMode) debugPrint('Error inicializando notificaciones: $e');
        });
      }
      
        _irAlPanelPropietario();
      } else {
        _mostrarError('Datos incorrectos');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route is! PopupRoute);
      }
      _mostrarError('No se pudo iniciar sesión. Verifica tus datos e intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  void _irAlPanelPropietario() {
    if (!mounted) return;
    context.go('/propietario');
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoIsoSize = (screenWidth * 0.44).clamp(138.0, 196.0);
    final logoLettersWidth = (screenWidth * 0.74).clamp(220.0, 340.0);
    final logoLettersHeight = (screenWidth * 0.15).clamp(48.0, 66.0);

    // Mostrar pantalla de carga mientras verifica sesión
    if (_verificandoSesion) {
      final logoWidth = (screenWidth * 0.62).clamp(220.0, 360.0);
      final lettersWidth = (screenWidth * 0.86).clamp(260.0, 460.0);
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + letras de marca
              Image.asset(
                'assets/FORTGUARD-LOGO.png',
                width: logoWidth,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              Image.asset(
                'assets/fortguard_letras.png',
                width: lettersWidth,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWaveDot(0),
                  const SizedBox(width: 12),
                  _buildWaveDot(1),
                  const SizedBox(width: 12),
                  _buildWaveDot(2),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      );
    }

    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('PROPIETARIO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/acceso-general'),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = constraints.maxWidth < 380 ? 12.0 : 24.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(sidePadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                const SizedBox(height: 8),
                // Logo FortGuard
                Image.asset(
                  'assets/FORTGUARD-LOGO.png',
                  width: logoIsoSize,
                  height: logoIsoSize,
                ),
                const SizedBox(height: 10),
                Image.asset(
                  'assets/fortguard_letras.png',
                  width: logoLettersWidth,
                  height: logoLettersHeight,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  'Propietarios',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _condominioController,
                  decoration: const InputDecoration(labelText: 'CONDOMINIO'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _casaController,
                  decoration: const InputDecoration(labelText: 'CASA'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'CONTRASEÑA'),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _isLoggingIn ? null : _login,
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Ingresar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                  ),
                ),
              ],
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
