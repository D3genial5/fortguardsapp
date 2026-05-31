import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/back_handler.dart';
import '../../services/ocr_service.dart';
import '../../core/feature_flags.dart';
import '../../services/secure_storage_service.dart';

class RegistroVisitaScreen extends StatefulWidget {
  const RegistroVisitaScreen({super.key});

  @override
  State<RegistroVisitaScreen> createState() => _RegistroVisitaScreenState();
}

class _RegistroVisitaScreenState extends State<RegistroVisitaScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ciController = TextEditingController();
  final _placaController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();

  final OcrService _ocrService = OcrService();
  
  File? _fotoCarnetFrente;
  File? _fotoCarnetReverso;
  File? _fotoPlaca;

  String? _ciOcrDetectado;
  bool _esExtranjero = false;
  
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _cargarDatosExistentes();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nombreController.dispose();
    _ciController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosExistentes() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = await SecureStorageService.getVisitanteNombre();
    final ci = await SecureStorageService.getVisitanteCi();
    final placa = prefs.getString('visitante_placa');

    if (nombre != null) _nombreController.text = nombre;
    if (ci != null) _ciController.text = ci;
    if (placa != null) _placaController.text = placa;
  }

  void _mostrarMensaje(String mensaje, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<bool> _validarCarnetConOcr() async {
    if (!FeatureFlags.ocrEnabled) return true;
    if (_esExtranjero) {
      _ciOcrDetectado = null;
      return true;
    }

    if (_fotoCarnetFrente == null || _fotoCarnetReverso == null) {
      _mostrarMensaje(
        'Sube el anverso y reverso del CI para validar tu identidad.',
        backgroundColor: Colors.orange,
      );
      return false;
    }

    try {
      final result = await _ocrService.validateId(
        frontImage: _fotoCarnetFrente!,
        backImage: _fotoCarnetReverso!,
      );

      if (!mounted) return false;

      if (!result.success) {
        _mostrarMensaje(
          'No se pudo validar el CI. ${result.reason ?? ''}',
          backgroundColor: Colors.red,
        );
        return false;
      }

      final ciIngresado = _ciController.text.trim();
      final ciOcr = result.idNumber?.trim() ?? '';
      if (ciOcr.isNotEmpty) {
        _ciOcrDetectado = ciOcr;
        if (ciIngresado.isEmpty) {
          _ciController.text = ciOcr;
        } else if (ciIngresado != ciOcr) {
          _mostrarMensaje(
            'El CI ingresado no coincide con el detectado ($ciOcr).',
            backgroundColor: Colors.red,
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      _mostrarMensaje(
        'Error validando el CI. Revisa tu conexión e intenta de nuevo.',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  Future<void> _seleccionarFoto(String tipo) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPhotoSourceSheet(),
    );
    
    if (source == null) return;
    
    try {
      final XFile? imagen = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (imagen == null) return;
      
      setState(() {
        switch (tipo) {
          case 'frente':
            _fotoCarnetFrente = File(imagen.path);
            break;
          case 'reverso':
            _fotoCarnetReverso = File(imagen.path);
            break;
          case 'placa':
            _fotoPlaca = File(imagen.path);
            break;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Widget _buildPhotoSourceSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Seleccionar imagen',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Cámara',
                color: Colors.blue,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _buildSourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Galería',
                color: Colors.purple,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _subirFoto(File foto, String nombre) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('visitantes')
          .child('${_ciController.text.trim()}_$nombre.jpg');
      
      final uploadTask = ref.putFile(foto);
      
      uploadTask.snapshotEvents.listen((event) {
        setState(() {
          _uploadProgress = event.bytesTransferred / event.totalBytes;
        });
      });
      
      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('Error subiendo foto: $e');
      return null;
    }
  }

  Future<void> _guardarYContinuar() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreController.text.trim();
    final ci = _ciController.text.trim();
    final placa = _placaController.text.trim();

    setState(() => _isLoading = true);

    final valido = await _validarCarnetConOcr();
    if (!valido) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
      }
      return;
    }

    try {
      String? urlCarnetFrente;
      String? urlCarnetReverso;
      String? urlPlaca;

      if (_fotoCarnetFrente != null) {
        urlCarnetFrente = await _subirFoto(_fotoCarnetFrente!, 'carnet_frente');
      }
      if (_fotoCarnetReverso != null) {
        urlCarnetReverso = await _subirFoto(_fotoCarnetReverso!, 'carnet_reverso');
      }
      if (_fotoPlaca != null) {
        urlPlaca = await _subirFoto(_fotoPlaca!, 'placa');
      }

      // Guardar en Firestore
      final visitanteData = {
        'nombre': nombre,
        'ci': ci,
        'placa': placa.isNotEmpty ? placa : null,
        'fotoCarnetFrente': urlCarnetFrente,
        'fotoCarnetReverso': urlCarnetReverso,
        'fotoPlaca': urlPlaca,
        'ciOcr': _esExtranjero ? null : _ciOcrDetectado,
        'ciValidado': !_esExtranjero,
        'esExtranjero': _esExtranjero,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'activo': true,
      };

      await FirebaseFirestore.instance
          .collection('visitantes')
          .doc(ci)
          .set(visitanteData, SetOptions(merge: true));

      // Guardar datos sensibles en almacenamiento seguro
      await SecureStorageService.saveVisitanteNombre(nombre);
      await SecureStorageService.saveVisitanteCi(ci);
      // Datos no sensibles en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (placa.isNotEmpty) {
        await prefs.setString('visitante_placa', placa);
      }
      await prefs.setBool('visitante_registrado', true);

      if (!mounted) return;

      // Mostrar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('¡Registro completado!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Esperar 2 segundos y mostrar diálogo de términos
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final acepto = await _mostrarDialogoTerminos();
      if (!mounted) return;

      if (acepto) {
        final p = await SharedPreferences.getInstance();
        await p.setBool('terminos_aceptados', true);
        if (!mounted) return;
        context.go('/acceso-general');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<bool> _mostrarDialogoTerminos() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.gavel_rounded, color: primary, size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Términos y Condiciones',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Por favor lee y acepta nuestros términos para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.normal),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Text(
                  'TÉRMINOS Y CONDICIONES DE USO / POLÍTICA DE PRIVACIDAD – APP FORTGUARDS\n'
                  'Última Actualización: 30 de marzo de 2026\n\n'
                  'El presente documento establece los Términos y Condiciones de Uso de la plataforma de administración de edificios y condominios denominada FORTGUARDS (en adelante APP) de propiedad de FORTGUARDSJ S.R.L. (en adelante, "LA EMPRESA"), destinada a la prestación de servicios para la administración de edificios y condominios, accesible a través de aplicación web y móvil.\n\n'
                  'El acceso y uso de la APP atribuye la condición de USUARIO (en adelante, el "USUARIO"), e implica la aceptación plena y sin reservas de todos los términos y condiciones establecidos en el presente documento.\n\n'
                  'En caso de que el USUARIO no esté de acuerdo con estos Términos y Condiciones, deberá abstenerse de utilizar la Plataforma.\n\n'
                  'PRIMERO — OBJETO DEL SERVICIO\n'
                  'El presente contrato tiene por objeto la prestación por el uso de una plataforma tecnológica en línea (software), denominada FORTGUARDS, tiene como propósito y finalidad apoyar la administración de edificios, oficinas y condominios sometidos al régimen de copropiedad.\n\n'
                  'SÉPTIMO — OBLIGACIONES DEL USUARIO\n'
                  'El USUARIO será plenamente responsable del uso que realice de la aplicación, comprometiéndose a utilizarla únicamente para fines lícitos.\n\n'
                  '• Mantener la confidencialidad de sus credenciales de acceso.\n'
                  '• No compartir contraseñas con terceros no autorizados.\n'
                  '• Utilizar dispositivos y redes seguras.\n'
                  '• Notificar oportunamente cualquier acceso no autorizado.\n\n'
                  'NOVENO — USO DE LA INFORMACIÓN Y PRIVACIDAD\n'
                  'LA EMPRESA tiene la obligación de asegurar la confidencialidad de la información almacenada en el sistema. LA EMPRESA no utilizará información del sistema con objetivos distintos a los que se informan al USUARIO.\n\n'
                  'PROTECCIÓN DE DATOS\n'
                  'El tratamiento de datos se realizará conforme a normativa boliviana vigente, garantizando seguridad y confidencialidad de la información.\n\n'
                  'Los datos serán utilizados para:\n'
                  '• Gestión administrativa del servicio.\n'
                  '• Procesamiento de pagos y comunicaciones.\n'
                  '• Seguridad, auditoría y prevención de fraude.\n'
                  '• Mejora del servicio.\n\n'
                  'Derechos del Usuario: El USUARIO podrá solicitar acceso, rectificación, eliminación, oposición y portabilidad de sus datos.\n\n'
                  'ACEPTACIÓN\n'
                  'El USUARIO declara haber leído, comprendido y aceptado íntegramente el contrato de TÉRMINOS Y CONDICIONES DE USO / POLÍTICA DE USO y sus anexos, los cuales tienen carácter obligatorio y vinculante.\n\n'
                  'Para consultar el documento completo, visite la sección "Términos y Condiciones" en el menú de la aplicación.\n\n'
                  'Contacto: +591 65867540 | fortguardbo@gmail.com\n'
                  'Documento FG-L-01 • Revisión 0.1/2026',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[700], height: 1.5),
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Acepto los Términos y Condiciones', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('No acepto', style: TextStyle(color: Colors.grey[500])),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return BackHandler(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withValues(alpha: 0.1),
                colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      title: Text(
                        'Registro de Visitante',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      centerTitle: true,
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.2),
                              colorScheme.secondary.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 48),
                            child: Icon(
                              Icons.person_add_rounded,
                              size: 48,
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header info
                            _buildInfoCard(colorScheme),
                            const SizedBox(height: 24),
                            
                            // Datos personales
                            _buildSectionTitle('Datos Personales', Icons.person_outline),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _nombreController,
                              label: 'Nombre completo',
                              hint: 'Ej: Juan Pérez García',
                              icon: Icons.badge_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'El nombre es obligatorio';
                                }
                                if (value.trim().length < 3) {
                                  return 'Ingresa tu nombre completo';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildExtranjeroToggle(colorScheme),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _ciController,
                              label: _esExtranjero
                                  ? 'Documento / Pasaporte'
                                  : 'Carnet de Identidad',
                              hint: _esExtranjero ? 'Ej: AB123456' : 'Ej: 12345678',
                              icon: Icons.credit_card_outlined,
                              keyboardType:
                                  _esExtranjero ? TextInputType.text : TextInputType.number,
                              textCapitalization: _esExtranjero
                                  ? TextCapitalization.characters
                                  : TextCapitalization.none,
                              inputFormatters: _esExtranjero
                                  ? [
                                      FilteringTextInputFormatter.allow(
                                        RegExp('[A-Za-z0-9]'),
                                      ),
                                    ]
                                  : [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return _esExtranjero
                                      ? 'El documento es obligatorio'
                                      : 'El CI es obligatorio';
                                }
                                if (value.trim().length < 5) {
                                  return _esExtranjero
                                      ? 'Documento inválido'
                                      : 'CI inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _placaController,
                              label: 'Placa del vehículo',
                              hint: 'Ej: ABC-1234 (opcional)',
                              icon: Icons.directions_car_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Fotos
                            _buildSectionTitle('Documentos', Icons.photo_camera_outlined),
                            const SizedBox(height: 8),
                            Text(
                              _esExtranjero
                                  ? 'Extranjero: CI frente/reverso no requerido.'
                                  : 'Agrega fotos de tu documentación (opcional para pruebas)',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPhotoSection(colorScheme),
                            
                            const SizedBox(height: 40),
                            
                            // Progress indicator
                            if (_isLoading && _uploadProgress > 0) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _uploadProgress,
                                  minHeight: 6,
                                  backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Subiendo fotos... ${(_uploadProgress * 100).toInt()}%',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Submit button
                            _buildSubmitButton(colorScheme),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
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

  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.1),
            colorScheme.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro único',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Solo necesitas registrarte una vez para solicitar acceso a cualquier condominio.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildExtranjeroToggle(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.public, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soy extranjero',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No se requiere CI frente/reverso.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _esExtranjero,
            onChanged: (value) {
              setState(() {
                _esExtranjero = value;
                if (value) {
                  _fotoCarnetFrente = null;
                  _fotoCarnetReverso = null;
                  _ciOcrDetectado = null;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPhotoSection(ColorScheme colorScheme) {
    if (_esExtranjero) {
      return Row(
        children: [
          Expanded(
            child: _buildPhotoCard(
              'Placa',
              Icons.directions_car,
              _fotoPlaca,
              () => _seleccionarFoto('placa'),
              colorScheme,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildPhotoCard(
            'CI Frente',
            Icons.credit_card,
            _fotoCarnetFrente,
            () => _seleccionarFoto('frente'),
            colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPhotoCard(
            'CI Reverso',
            Icons.flip,
            _fotoCarnetReverso,
            () => _seleccionarFoto('reverso'),
            colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPhotoCard(
            'Placa',
            Icons.directions_car,
            _fotoPlaca,
            () => _seleccionarFoto('placa'),
            colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(
    String label,
    IconData icon,
    File? foto,
    VoidCallback onTap,
    ColorScheme colorScheme,
  ) {
    final hasFoto = foto != null;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: 120,
        decoration: BoxDecoration(
          color: hasFoto 
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFoto 
                ? colorScheme.primary 
                : colorScheme.outline.withValues(alpha: 0.3),
            width: hasFoto ? 2 : 1,
          ),
          boxShadow: hasFoto
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: hasFoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(foto, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: colorScheme.primary.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.add_circle_outline,
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      size: 16,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _guardarYContinuar,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Completar Registro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
