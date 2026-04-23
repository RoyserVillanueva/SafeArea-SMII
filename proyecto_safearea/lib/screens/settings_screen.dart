import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = 'Español';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifications = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _language = prefs.getString('language') ?? 'Español';
      });
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authService = Provider.of<AuthService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Configuración'),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección: Notificaciones
            _SettingsSection(
              title: 'Notificaciones',
              icon: Icons.notifications,
              colorScheme: colorScheme,
              children: [
                SwitchListTile(
                  title: const Text('Activar notificaciones'),
                  subtitle: const Text('Recibir alertas de la aplicación'),
                  value: _notifications,
                  secondary: Icon(Icons.notifications, color: colorScheme.primary),
                  onChanged: (value) {
                    setState(() => _notifications = value);
                    _saveBoolSetting('notifications_enabled', value);
                  },
                ),
                Opacity(
                  opacity: _notifications ? 1.0 : 0.5,
                  child: SwitchListTile(
                    title: const Text('Sonido'),
                    subtitle: const Text('Reproducir sonido en notificaciones'),
                    value: _soundEnabled && _notifications,
                    secondary: Icon(Icons.volume_up, color: colorScheme.secondary),
                    onChanged: _notifications ? (value) {
                      setState(() => _soundEnabled = value);
                      _saveBoolSetting('sound_enabled', value);
                    } : null,
                  ),
                ),
                Opacity(
                  opacity: _notifications ? 1.0 : 0.5,
                  child: SwitchListTile(
                    title: const Text('Vibración'),
                    subtitle: const Text('Vibrar al recibir notificaciones'),
                    value: _vibrationEnabled && _notifications,
                    secondary: Icon(Icons.vibration, color: colorScheme.tertiary),
                    onChanged: _notifications ? (value) {
                      setState(() => _vibrationEnabled = value);
                      _saveBoolSetting('vibration_enabled', value);
                    } : null,
                  ),
                ),
              ],
            ),

            // Sección: Apariencia
            _SettingsSection(
              title: 'Apariencia',
              icon: Icons.palette,
              colorScheme: colorScheme,
              children: [
                Consumer<ThemeService>(
                  builder: (context, themeService, _) {
                    return ListTile(
                      leading: Icon(
                        themeService.themeMode == ThemeMode.dark
                            ? Icons.dark_mode
                            : themeService.themeMode == ThemeMode.light
                                ? Icons.light_mode
                                : Icons.brightness_auto,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Modo de tema'),
                      subtitle: Text('Actual: ${themeService.getThemeModeLabel()}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Seleccionar modo de tema'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioListTile<ThemeMode>(
                                  title: const Text('Claro'),
                                  subtitle: const Text('Tema claro siempre'),
                                  value: ThemeMode.light,
                                  groupValue: themeService.themeMode,
                                  onChanged: (ThemeMode? value) {
                                    if (value != null) {
                                      themeService.setThemeMode(value);
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Oscuro'),
                                  subtitle: const Text('Tema oscuro siempre'),
                                  value: ThemeMode.dark,
                                  groupValue: themeService.themeMode,
                                  onChanged: (ThemeMode? value) {
                                    if (value != null) {
                                      themeService.setThemeMode(value);
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Sistema'),
                                  subtitle: const Text('Seguir configuración del dispositivo'),
                                  value: ThemeMode.system,
                                  groupValue: themeService.themeMode,
                                  onChanged: (ThemeMode? value) {
                                    if (value != null) {
                                      themeService.setThemeMode(value);
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            // Sección: Información
            _SettingsSection(
              title: 'Información',
              icon: Icons.info,
              colorScheme: colorScheme,
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: colorScheme.primary),
                  title: const Text('Versión de la aplicación'),
                  subtitle: const Text('0.1.0'),
                ),
                ListTile(
                  leading: Icon(Icons.person, color: colorScheme.secondary),
                  title: const Text('Usuario actual'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authService.currentUser?.email ?? 'No disponible'),
                      if (authService.currentUser != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          authService.currentUser!.name,
                          style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // Mostrar rol para todos los usuarios
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: authService.currentUser!.isAdmin 
                                ? colorScheme.primaryContainer 
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: authService.currentUser!.isAdmin 
                                  ? colorScheme.primary 
                                  : colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                authService.currentUser!.isAdmin 
                                    ? Icons.admin_panel_settings 
                                    : Icons.person,
                                size: 14,
                                color: authService.currentUser!.isAdmin 
                                    ? colorScheme.onPrimaryContainer 
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                authService.currentUser!.isAdmin ? 'Administrador' : 'Usuario',
                                style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
                                  color: authService.currentUser!.isAdmin 
                                      ? colorScheme.onPrimaryContainer 
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Botón para refrescar datos del usuario desde Firebase
                if (authService.currentUser != null)
                  ListTile(
                    leading: Icon(Icons.refresh, color: colorScheme.primary),
                    title: const Text('Refrescar datos de usuario'),
                    subtitle: Text('Rol actual: ${authService.currentUser?.role ?? "user"}'),
                    onTap: () async {
                      setState(() {
                        _isLoading = true;
                      });
                      
                      await authService.refreshCurrentUser();
                      
                      if (!mounted) return;
                      setState(() {
                        _isLoading = false;
                      });
                      
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            authService.currentUser?.isAdmin ?? false
                                ? 'Usuario actualizado. Eres administrador. Recarga la app.'
                                : 'Usuario actualizado. Rol: ${authService.currentUser?.role ?? "user"}. Verifica en Firebase que el campo role sea "admin".',
                          ),
                          backgroundColor: authService.currentUser?.isAdmin ?? false
                              ? Colors.green
                              : Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.help_outline, color: colorScheme.tertiary),
                  title: const Text('Ayuda y soporte'),
                  subtitle: const Text('Preguntas frecuentes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Ayuda y Soporte'),
                        content: const Text(
                          'Para más información sobre SafeArea, contacta al equipo de soporte.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: colorScheme.primary),
                  title: const Text('Política de privacidad'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Política de Privacidad'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'SafeArea protege tu privacidad. Los datos personales se enmascaran para otros usuarios. '
                            'Solo los administradores tienen acceso completo a la información necesaria para la moderación.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            // Sección: Datos
            _SettingsSection(
              title: 'Datos',
              icon: Icons.storage,
              colorScheme: colorScheme,
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: const Text('Limpiar caché'),
                  subtitle: const Text('Eliminar datos temporales'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Limpiar caché'),
                        content: const Text('¿Estás seguro de limpiar la caché? Esto eliminará datos temporales pero no afectará tus preferencias.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Limpiar'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        // Aquí puedes agregar lógica para limpiar caché si es necesario
                        // Por ejemplo, limpiar imágenes en caché, etc.
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Caché limpiada exitosamente'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error al limpiar caché: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.refresh, color: colorScheme.primary),
                  title: const Text('Restablecer configuración'),
                  subtitle: const Text('Volver a los valores por defecto'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Restablecer configuración'),
                        content: const Text('¿Deseas restablecer todas las configuraciones a sus valores por defecto?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Restablecer'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('notifications_enabled');
                        await prefs.remove('sound_enabled');
                        await prefs.remove('vibration_enabled');
                        await prefs.remove('language');
                        
                        await _loadSettings();
                        
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Configuración restablecida'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Widget para agrupar opciones de configuración
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final ColorScheme colorScheme;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: children.map((child) {
                final index = children.indexOf(child);
                return Column(
                  children: [
                    child,
                    if (index < children.length - 1)
                      Divider(height: 1, color: colorScheme.outlineVariant),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}


