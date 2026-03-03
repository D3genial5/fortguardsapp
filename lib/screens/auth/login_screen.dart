import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
    final condominio = _condominioController.text.trim();
    final casa = _casaController.text.trim();
    final password = _passwordController.text.trim();

    if (condominio.isEmpty || casa.isEmpty || password.isEmpty) {
      _mostrarError('Completa todos los campos');
      return;
    }

    // Mostrar cargando
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

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
      final casaNumero = data['casa']['numero'] as int;
      final condominioId = data['condominio'] as String;
      
      // Buscar o crear credencial del usuario
      final credencialQuery = await FirebaseFirestore.instance
          .collection('credenciales')
          .where('condominio', isEqualTo: condominioId)
          .where('casa', isEqualTo: casaNumero)
          .where('tipo', isEqualTo: 'propietario')
          .limit(1)
          .get();
      
      String userId;
      if (credencialQuery.docs.isNotEmpty) {
        userId = credencialQuery.docs.first.id;
      } else {
        // Crear nueva credencial si no existe
        final newCredencial = await FirebaseFirestore.instance.collection('credenciales').add({
          'condominio': condominioId,
          'casa': casaNumero,
          'tipo': 'propietario',
          'password': password,
          'createdAt': FieldValue.serverTimestamp(),
        });
        userId = newCredencial.id;
      }
      
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
        _notificationService.initialize(userId).then((_) {
          _notificationService.subscribeToCondominio(condominioId);
        }).catchError((e) {
          debugPrint('Error inicializando notificaciones: $e');
        });
      }
      
      _irAlPanelPropietario();
    } else {
      _mostrarError('Datos incorrectos');
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
    final splashIsoSize = (screenWidth * 0.3).clamp(96.0, 132.0);
    final splashLettersWidth = (screenWidth * 0.5).clamp(170.0, 240.0);
    final loadingFontSize = (screenWidth * 0.08).clamp(26.0, 32.0);

    // Mostrar pantalla de carga mientras verifica sesión
    if (_verificandoSesion) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo FortGuard
              Image.asset(
                'assets/FORTGUARD-ISO1.png',
                width: splashIsoSize,
                height: splashIsoSize,
              ),
              const SizedBox(height: 20),
              Image.asset(
                'assets/fortguard_letras.png',
                width: splashLettersWidth,
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
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
              Text(
                'CARGANDO',
                style: TextStyle(
                  fontSize: loadingFontSize,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  letterSpacing: 1.2,
                  color: Color(0xFF1A1A1A),
                ),
              ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo FortGuard
                Image.asset(
                  'assets/FORTGUARD-ISO1.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/fortguard_letras.png',
                  width: 180,
                  height: 35,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  'Propietarios',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
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
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: _login,
                    child: const Text('Ingresar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
