import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/solicitud_model.dart';

class SolicitudService {
  static const _key = 'solicitudes';

  /// Obtener todas las solicitudes guardadas
  static Future<List<SolicitudModel>> obtenerSolicitudes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((e) => SolicitudModel.fromJson(jsonDecode(e))).toList();
  }

  /// Guardar una nueva solicitud
  static Future<void> guardarSolicitud(SolicitudModel solicitud) async {
    final prefs = await SharedPreferences.getInstance();
    final solicitudes = await obtenerSolicitudes();
    solicitudes.add(solicitud);
    final jsonList = solicitudes.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  /// Actualizar estado de una solicitud por coincidencia exacta
  static Future<void> actualizarEstado(SolicitudModel solicitudOriginal, String nuevoEstado) async {
    final prefs = await SharedPreferences.getInstance();
    final solicitudes = await obtenerSolicitudes();

    final index = solicitudes.indexWhere((s) =>
      s.ci == solicitudOriginal.ci &&
      s.condominio == solicitudOriginal.condominio &&
      s.casaNumero == solicitudOriginal.casaNumero &&
      s.fecha == solicitudOriginal.fecha,
    );

    if (index != -1) {
      final actualizada = SolicitudModel(
        nombre: solicitudOriginal.nombre,
        apellidos: solicitudOriginal.apellidos,
        ci: solicitudOriginal.ci,
        condominio: solicitudOriginal.condominio,
        casaNumero: solicitudOriginal.casaNumero,
        fecha: solicitudOriginal.fecha,
        estado: nuevoEstado,
      );

      solicitudes[index] = actualizada;
      final jsonList = solicitudes.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_key, jsonList);
    }
  }

  /// Filtrar solicitudes por condominio y casa
  static Future<List<SolicitudModel>> obtenerPorCasa(String condominio, int casa) async {
    final solicitudes = await obtenerSolicitudes();
    return solicitudes.where((s) =>
      s.condominio == condominio &&
      s.casaNumero == casa
    ).toList();
  }
}
