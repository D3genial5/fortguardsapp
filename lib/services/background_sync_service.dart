import 'package:flutter/material.dart';

/// Servicio de sincronización en background
/// NOTA: Workmanager temporalmente deshabilitado por incompatibilidad
/// Las notificaciones push (PushNotificationService) funcionan normalmente
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();
  
  /// Inicializar servicio (actualmente deshabilitado)
  Future<void> initialize() async {
    debugPrint('⚠️  Background sync service disabled - waiting for workmanager update');
    // TODO: Re-enable when workmanager is updated to compatible version
  }
  
  /// Registrar tareas periódicas (actualmente deshabilitado)
  Future<void> registerPeriodicTasks() async {
    debugPrint('⚠️  Periodic tasks disabled - waiting for workmanager update');
    // TODO: Re-enable when workmanager is updated to compatible version
  }
  
  /// Sincronizar ahora (actualmente deshabilitado)
  Future<void> syncNow() async {
    debugPrint('⚠️  Manual sync disabled - waiting for workmanager update');
    // TODO: Re-enable when workmanager is updated to compatible version
  }
  
  /// Cancelar todas las tareas (actualmente deshabilitado)
  Future<void> cancelAllTasks() async {
    debugPrint('⚠️  Cancel tasks disabled - waiting for workmanager update');
    // TODO: Re-enable when workmanager is updated to compatible version
  }
}
