import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme_manager.dart';

class AccesoGeneralScreen extends StatelessWidget {
  const AccesoGeneralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        title: const Text('Fortguard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAccesoButton(
              context,
              label: 'PROPIETARIO',
              icon: Icons.person_outline_rounded,
              onPressed: () => context.push('/login'),
            ),
            const SizedBox(height: 16),
            _buildAccesoButton(
              context,
              label: 'VISITA',
              icon: Icons.lock_outline_rounded,
              onPressed: () => context.push('/seleccion-accion'),
            ),
            const SizedBox(height: 16),
            _buildAccesoButton(
              context,
              label: 'INVITADOS',
              icon: Icons.assignment_ind_outlined,
              onPressed: () => context.push('/mi-qr'),
            ),
            const SizedBox(height: 16),
            _buildAccesoButton(
              context,
              label: "MIS QR'S",
              icon: Icons.qr_code_2_rounded,
              onPressed: () => context.push('/mis-qrs'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesoButton(BuildContext context,
      {required String label, required IconData icon, required VoidCallback onPressed}) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
      ),
    );
  }

  Drawer _buildAppDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: Icon(Icons.help_center, color: scheme.primary),
              title: const Text('Centro de ayuda'),
              onTap: () => context.push('/help'),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: scheme.primary),
              title: const Text('Acerca de nosotros'),
              onTap: () => context.push('/about'),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: scheme.primary),
              title: const Text('Términos y condiciones'),
              onTap: () => context.push('/terms'),
            ),
            const Divider(),
            SwitchListTile(
              secondary: Icon(Icons.brightness_6, color: scheme.primary),
              title: const Text('Tema oscuro'),
              value: ThemeManager.notifier.value == ThemeMode.dark,
              onChanged: (_) => ThemeManager.toggle(),
            ),
          ],
        ),
      ),
    );
  }
}
