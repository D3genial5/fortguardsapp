import 'dart:convert';
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

class _LoginScreenState extends State<LoginScreen> {
  final _condominioController = TextEditingController();
  final _casaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sessionService = SessionService();
  final _notificationService = NotificationService();
  
  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }
  
  Future<void> _checkExistingSession() async {
    // Verificar si ya hay una sesión activa
    final sessionActive = await _sessionService.isSessionActive();
    if (sessionActive && mounted) {
      context.go('/propietario');
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
        _notificationService.initialize(context, userId).then((_) {
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
    return BackHandler(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('PROPIETARIO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/acceso-general'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            ElevatedButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: _login,
              child: const Text('Ingresar'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
