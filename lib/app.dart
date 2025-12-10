import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/login_screen.dart';
import 'screens/personal/registro_visita_screen.dart';
import 'screens/personal/seleccion_accion_screen.dart';
import 'screens/acceso/acceso_general_screen.dart';
import 'screens/visita/seleccion_condo.dart';
import 'screens/visita/qr_casa_screen.dart';
import 'screens/propietario/panel_propietario_screen.dart';
import 'screens/qr/solicitud_qr_screen.dart';
import 'screens/qr/mi_qr_screen.dart';
import 'screens/qr/mis_qrs_screen.dart';
import 'theme_manager.dart';
import 'app_theme.dart';
import 'screens/common/help_center_screen.dart';
import 'screens/common/about_screen.dart';
import 'screens/common/terms_screen.dart';


final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RegistroVisitaScreen(),
    ),

    GoRoute(
      path: '/acceso-general',
      builder: (context, state) => const AccesoGeneralScreen(),
    ),

    GoRoute(
      path: '/seleccion-accion',
      builder: (context, state) => const SeleccionAccionScreen(),
    ),

    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/seleccion-condominio',
      builder: (context, state) => const SeleccionCondominioScreen(),
    ),

    GoRoute(
      path: '/qr-casa',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return QrCasaScreen(
          casa: data['casa']?.toString() ?? '',
          condominio: data['condominio']?.toString() ?? '',
          docId: data['docId']?.toString(),
          tipoAcceso: data['tipoAcceso']?.toString(),
          usosRestantes: data['usosRestantes'] as int?,
          codigoQr: data['codigoQr']?.toString(),
          fechaExpiracion: data['fechaExpiracion']?.toString(),
        );
      },
    ),
    // TODO boton de poner opcion de usos
    GoRoute(
      path: '/propietario',
      builder: (context, state) => const PanelPropietarioScreen(),
    ),

    GoRoute(
      path: '/mis-qrs',
      builder: (context, state) => const MisQrsScreen(),
    ),

    GoRoute(
      path: '/mi-qr',
      builder: (context, state) => const MiQrScreen(),
    ),

    GoRoute(
      path: '/solicitud-acceso',
      builder: (context, state) => const SolicitudQrScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpCenterScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsScreen(),
    ),
  ],
);



class FortGuards extends StatelessWidget {
  const FortGuards({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.notifier,
      builder: (context, mode, _) {
        return MaterialApp.router(
      routerConfig: _router,
      title: 'Gestión de Condominios',
      themeMode: mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
    );
  },
);
  }
}
