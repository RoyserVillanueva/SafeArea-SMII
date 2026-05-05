import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/auth_text_field.dart';
import '../theme/app_theme.dart';
import 'phone_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _storageService = StorageService();
  bool _isEditing = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _nameController.text = authService.currentUser?.name ?? ''; 
    _phoneController.text = authService.currentUser?.phone ?? '';
    _photoUrlController.text = authService.currentUser?.profileImage ?? '';
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // RF-03: Subir foto de perfil desde cámara o galería
  Future<void> _pickProfilePhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar foto de perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photoUrlController.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Eliminar foto'),
                onTap: () async {
                  Navigator.pop(context);

                  final authService = Provider.of<AuthService>(context, listen: false);

                  setState(() {
                    _isUploadingPhoto = true;
                  });

                  final error = await authService.updateProfile(
                    _nameController.text,
                    _phoneController.text.isEmpty ? null : _phoneController.text,
                    profileImage: null,
                  );

                  if (!mounted) return;

                  setState(() {
                    _photoUrlController.clear();
                    _isUploadingPhoto = false;
                  });

                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Foto de perfil eliminada correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar foto de perfil: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _storageService.pickImage(source: source);
      if (image == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó ninguna imagen')),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      debugPrint('Iniciando subida de imagen...');
      final imageUrl = await _storageService.uploadImageFile(
        file: image,
        folder: 'profile',
        fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint('Imagen subida exitosamente: $imageUrl');
        
        // Actualizar el controlador
        setState(() {
          _photoUrlController.text = imageUrl;
          _isUploadingPhoto = false;
        });

        // Guardar automáticamente el perfil con la nueva foto
        final authService = Provider.of<AuthService>(context, listen: false);
        final error = await authService.updateProfile(
          _nameController.text,
          _phoneController.text.isEmpty ? null : _phoneController.text,
          profileImage: imageUrl,
        );

        if (!mounted) return;

        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          // Forzar actualización del UI
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto subida pero error al actualizar perfil: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _isUploadingPhoto = false;
        });
        debugPrint('Error: imageUrl es null o vacío');
        _showErrorDialog(
          context,
          'Error al subir foto',
          'No se pudo obtener la URL de la imagen subida. Verifica:\n\n'
          '1. Las reglas de Firebase Storage\n'
          '2. Que estés autenticado\n'
          '3. La consola del navegador para más detalles',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error completo al subir foto: $e');
      debugPrint('StackTrace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
      });
      
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      _showErrorDialog(
        context,
        'Error al subir foto',
        errorMessage,
      );
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Abrir documentación
              // Puedes agregar un enlace a la documentación aquí
            },
            child: const Text('Ver ayuda'),
          ),
        ],
      ),
    );
  }

  void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final error = await authService.updateProfile(
        _nameController.text,
        _phoneController.text.isEmpty ? null : _phoneController.text,
        profileImage: _photoUrlController.text.isEmpty ? null : _photoUrlController.text,
      );

      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado exitosamente')),
        );
        _toggleEdit();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Consumer<AuthService>(
                  builder: (context, auth, __) {
                    final photo = _photoUrlController.text.isNotEmpty 
                        ? _photoUrlController.text 
                        : auth.currentUser?.profileImage;
                    final colorScheme = Theme.of(context).colorScheme;
                    return Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: colorScheme.surface,
                              child: CircleAvatar(
                                radius: 52,
                                backgroundImage: (photo != null && photo.isNotEmpty)
                                    ? NetworkImage(photo)
                                    : null,
                                child: (photo == null || photo.isEmpty)
                                    ? Icon(Icons.person, size: 56, color: AppTheme.primaryColor)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        // RF-03: Botón para cambiar foto
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.surface, width: 3),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isUploadingPhoto ? null : _pickProfilePhoto,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: _isUploadingPhoto
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              colorScheme.onPrimary,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.camera_alt,
                                          size: 20,
                                          color: colorScheme.onPrimary,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                // Formulario con card
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        AuthTextField(
                          label: 'Nombre',
                          icon: Icons.person,
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        AuthTextField(
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          controller: TextEditingController(text: authService.currentUser?.email ?? ''), 
                        ),
                        const SizedBox(height: 12),
                        
                        AuthTextField(
                          label: 'Teléfono',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          controller: _phoneController,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                            if (!phoneRegex.hasMatch(value)) return 'Ingresa un teléfono válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // 🔐 NUEVO: Botón para validar número de teléfono (solo si no está validado)
                        Consumer<AuthService>(
                          builder: (context, authService, _) {
                            if (!authService.hasVerifiedPhone) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.verified_user, size: 18),
                                  label: const Text('Validar número de teléfono'),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PhoneVerificationScreen(),
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      // Recargar datos del usuario después de validar
                                      await authService.refreshCurrentUser();
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Número de teléfono verificado correctamente'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                              );
                            } else {
                              // Si ya está validado, mostrar indicador
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified, color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Teléfono verificado: ${authService.userPhoneNumber ?? _phoneController.text}',
                                          style: const TextStyle(color: Colors.green, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        // RF-03: Botón para subir foto
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Cambiar foto de perfil'),
                          onPressed: _isUploadingPhoto ? null : _pickProfilePhoto,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: authService.isLoading ? null : _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: authService.isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                        ),
                                      )
                                    : Text(
                                        'Guardar Cambios',
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _toggleEdit,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }
}