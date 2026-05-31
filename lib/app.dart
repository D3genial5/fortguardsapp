import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
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
import 'screens/common/help_center_screen.dart';
import 'screens/common/about_screen.dart';
import 'screens/common/terms_screen.dart';
import 'screens/common/splash_screen.dart';

/// Rutas que NO requieren sesión de propietario.
const _publicRoutes = <String>{
  '/',
  '/splash',
  '/login',
  '/seleccion-accion',
  '/acceso-general',
  '/seleccion-condominio',
  '/qr-casa',
  '/help',
  '/about',
  '/terms',
};

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final loc = state.matchedLocation;
    if (_publicRoutes.contains(loc)) return null;

    // Rutas protegidas: requieren Firebase Auth (Custom Token de propietario)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid.startsWith('prop_')) return null;

    // Fallback: si tiene sesión legacy en SharedPreferences, dejamos pasar pero
    // mostramos un splash que dispara el login real.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('propietario') != null) return null;

    return '/login';
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/', builder: (_, __) => const RegistroVisitaScreen()),
    GoRoute(path: '/acceso-general', builder: (_, __) => const AccesoGeneralScreen()),
    GoRoute(path: '/seleccion-accion', builder: (_, __) => const SeleccionAccionScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/seleccion-condominio', builder: (_, __) => const SeleccionCondominioScreen()),
    GoRoute(
      path: '/qr-casa',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! Map<String, dynamic>) {
          return const Scaffold(body: Center(child: Text('Datos de QR faltantes')));
        }
        return QrCasaScreen(
          casa: extra['casa']?.toString() ?? '',
          condominio: extra['condominio']?.toString() ?? '',
          docId: extra['docId']?.toString(),
          tipoAcceso: extra['tipoAcceso']?.toString(),
          usosRestantes: extra['usosRestantes'] as int?,
          codigoQr: extra['codigoQr']?.toString(),
          fechaExpiracion: extra['fechaExpiracion']?.toString(),
          esSalida: extra['esSalida'] as bool? ?? false,
          forzarCodigoCasa: extra['forzarCodigoCasa'] as bool? ?? false,
        );
      },
    ),
    GoRoute(path: '/propietario', builder: (_, __) => const PanelPropietarioScreen()),
    GoRoute(path: '/mis-qrs', builder: (_, __) => const MisQrsScreen()),
    GoRoute(path: '/mi-qr', builder: (_, __) => const MiQrScreen()),
    GoRoute(path: '/solicitud-acceso', builder: (_, __) => const SolicitudQrScreen()),
    GoRoute(path: '/help', builder: (_, __) => const HelpCenterScreen()),
    GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
    GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
  ],
);

class FortGuards extends StatelessWidget {
  const FortGuards({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'FortGuards',
      themeMode: ThemeMode.light,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}
