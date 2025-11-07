import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme_manager.dart';
import '../../widgets/back_handler.dart';

class AccesoGeneralScreen extends StatelessWidget {
  const AccesoGeneralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackHandler(
      child: Scaffold(
        drawer: _buildAppDrawer(context),
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'letrasFortguards2.png',
          height: 28,
          fit: BoxFit.contain,
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Calcular tamaño óptimo de botones
          final horizontalPadding = 32.0;
          final buttonGap = 16.0;
          final buttonWidth = (screenWidth - (horizontalPadding * 2) - buttonGap) / 2;
          final buttonHeight = buttonWidth * 1.35; // Ratio rectangular vertical óptimo
          
          // Calcular altura total necesaria
          final totalHeight = (buttonHeight * 2) + buttonGap;
          final topPadding = (screenHeight - totalHeight) / 2;
          
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: topPadding.clamp(40, double.infinity),
                bottom: 40,
              ),
              child: Stack(
                children: [
                  // Grid 2x2
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila superior
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildGridButton(
                            context,
                            label: 'PROPIETARIO',
                            icon: Icons.person,
                            width: buttonWidth,
                            height: buttonHeight,
                            onPressed: () => context.push('/login'),
                          ),
                          SizedBox(width: buttonGap),
                          _buildGridButton(
                            context,
                            label: 'VISITA',
                            icon: Icons.lock,
                            width: buttonWidth,
                            height: buttonHeight,
                            onPressed: () => context.push('/seleccion-accion'),
                          ),
                        ],
                      ),
                      SizedBox(height: buttonGap),
                      // Fila inferior
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildGridButton(
                            context,
                            label: 'INVITADOS',
                            icon: Icons.content_paste,
                            width: buttonWidth,
                            height: buttonHeight,
                            onPressed: () => context.push('/mi-qr'),
                          ),
                          SizedBox(width: buttonGap),
                          _buildGridButton(
                            context,
                            label: "MIS QR'S",
                            icon: Icons.qr_code_2,
                            width: buttonWidth,
                            height: buttonHeight,
                            onPressed: () => context.push('/mis-qrs'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Logo central
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            'logoFortguards.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildGridButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required double width,
    required double height,
    required VoidCallback onPressed,
  }) {
    return _AnimatedGridButton(
      label: label,
      icon: icon,
      width: width,
      height: height,
      onPressed: onPressed,
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

class _AnimatedGridButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final double width;
  final double height;
  final VoidCallback onPressed;

  const _AnimatedGridButton({
    required this.label,
    required this.icon,
    required this.width,
    required this.height,
    required this.onPressed,
  });

  @override
  State<_AnimatedGridButton> createState() => _AnimatedGridButtonState();
}

class _AnimatedGridButtonState extends State<_AnimatedGridButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                Color.lerp(scheme.primary, Colors.black, 0.15)!,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: -1,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.25),
                      blurRadius: 14,
                      spreadRadius: -6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: scheme.onPrimary,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
