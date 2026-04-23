import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'chat_groups_screen.dart';
import 'users_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: true); // Escuchar cambios
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    // Debug: mostrar rol actual
    debugPrint('HomeScreen - Rol del usuario: ${authService.currentUser?.role}, isAdmin: ${authService.currentUser?.isAdmin}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeArea'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de bienvenida con azul claro
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.primary, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.security, size: 32, color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, ${authService.currentUser?.name ?? 'Usuario'}',
                            style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authService.currentUser?.email ?? '',
                            style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Título de sección
            Text(
              'Funcionalidades',
              style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Grid de funcionalidades según rol
            GridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                // Altura fija razonable para cada card; el scroll externo se encarga del resto
                mainAxisExtent: 220,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _buildFeaturesByRole(context, authService, colorScheme),
            ),

            const SizedBox(height: 12),

            // Información rápida con estilo moderno
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.primary, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.info, color: colorScheme.primary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SafeArea Community',
                            style: (textTheme.titleSmall ?? const TextStyle()).copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mantente informado sobre la seguridad de tu comunidad',
                            style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye las funcionalidades según el rol del usuario
  List<Widget> _buildFeaturesByRole(
    BuildContext context,
    AuthService authService,
    ColorScheme colorScheme,
  ) {
    final isAdmin = authService.currentUser?.isAdmin ?? false;

    if (isAdmin) {
      // ADMINISTRADOR: Panel de Administración (RF-15, RF-16, RF-17, RF-18)
      return [
        // Dashboard (RF-15)
        _buildFeatureCard(
          icon: Icons.analytics,
          title: 'Dashboard',
          subtitle: 'Estadísticas y actividad',
          color: colorScheme.primary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          },
        ),
        // Gestión de Usuarios (RF-16)
        _buildFeatureCard(
          icon: Icons.group,
          title: 'Usuarios',
          subtitle: 'Gestión de usuarios',
          color: colorScheme.secondary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UsersScreen()),
            );
          },
        ),
        // Moderación de Reportes (RF-17)
        _buildFeatureCard(
          icon: Icons.report,
          title: 'Reportes',
          subtitle: 'Moderar reportes',
          color: colorScheme.error,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportsScreen()),
            );
          },
        ),
        // Configuración de App (RF-18)
        _buildFeatureCard(
          icon: Icons.settings,
          title: 'Configuración',
          subtitle: 'Ajustes de la app',
          color: colorScheme.onSurfaceVariant,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        // Chat (también disponible para admins)
        _buildFeatureCard(
          icon: Icons.chat,
          title: 'Chat',
          subtitle: 'Grupos de chat',
          color: colorScheme.tertiary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatGroupsScreen(),
              ),
            );
          },
        ),
        // Mi Perfil
        _buildFeatureCard(
          icon: Icons.person,
          title: 'Mi Perfil',
          subtitle: 'Gestionar cuenta',
          color: colorScheme.secondary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
      ];
    } else {
      // USUARIO: Gestión de Reportes (RF-05, RF-06, RF-07, RF-08, RF-09) + Chat Comunitario (RF-10, RF-11, RF-12, RF-13, RF-14) + Configuración (RF-18)
      return [
        // Reportes (RF-05: Crear, RF-06: Categorización, RF-07: Gestión estados, RF-08: Edición, RF-09: Listado)
        _buildFeatureCard(
          icon: Icons.report,
          title: 'Reportes',
          subtitle: 'Crear y gestionar reportes',
          color: colorScheme.primary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportsScreen()),
            );
          },
        ),
        // Chat Grupal (RF-10)
        _buildFeatureCard(
          icon: Icons.chat,
          title: 'Chat',
          subtitle: 'Grupos de chat',
          color: colorScheme.tertiary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatGroupsScreen(),
              ),
            );
          },
        ),
        // Configuración de App (RF-18) - Disponible para todos los usuarios
        _buildFeatureCard(
          icon: Icons.settings,
          title: 'Configuración',
          subtitle: 'Ajustes de la app',
          color: colorScheme.onSurfaceVariant,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        // Mi Perfil
        _buildFeatureCard(
          icon: Icons.person,
          title: 'Mi Perfil',
          subtitle: 'Gestionar cuenta',
          color: colorScheme.secondary,
          context: context,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
      ];
    }
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(icon, color: colorScheme.primary, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                  color: colorScheme.onSurfaceVariant,
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
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<AuthService>(context, listen: false).logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: Text(
                'Cerrar Sesión',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}