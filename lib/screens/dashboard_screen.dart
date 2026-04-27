import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    // RF-15: Solo administradores pueden acceder al Dashboard
    if (currentUser == null || !currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          elevation: 0,
        ),
        body: const _AccessDeniedWidget(
          message: 'Solo los administradores pueden acceder al Dashboard.',
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estadísticas principales
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, reportsSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, usersSnapshot) {
                    final totalReports = reportsSnapshot.data?.docs.length ?? 0;
                    final totalUsers = usersSnapshot.data?.docs.length ?? 0;
                    
                    // Contar reportes por estado
                    int activeReports = 0;
                    int inProcessReports = 0;
                    int resolvedReports = 0;
                    
                    final reports = reportsSnapshot.data?.docs ?? [];
                    for (final doc in reports) {
                      final data = doc.data() as Map<String, dynamic>?;
                      final reportStatus = data?['status'] as String?;
                      if (reportStatus == 'activo') {
                        activeReports++;
                      } else if (reportStatus == 'en_proceso') {
                        inProcessReports++;
                      } else if (reportStatus == 'resuelto') {
                        resolvedReports++;
                      }
                    }

                    return Column(
                      children: [
                        // Cards de estadísticas
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Total Reportes',
                                value: totalReports.toString(),
                                icon: Icons.report,
                                color: colorScheme.primary,
                                gradient: AppTheme.primaryGradient,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Total Usuarios',
                                value: totalUsers.toString(),
                                icon: Icons.group,
                                color: colorScheme.secondary,
                                gradient: AppTheme.secondaryGradient,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Reportes por estado
                        Text(
                          'Reportes por Estado',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Activos',
                                value: activeReports.toString(),
                                icon: Icons.warning,
                                color: Colors.orange,
                                gradient: LinearGradient(
                                  colors: [Colors.orange, Colors.deepOrange],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'En Proceso',
                                value: inProcessReports.toString(),
                                icon: Icons.sync,
                                color: Colors.blue,
                                gradient: LinearGradient(
                                  colors: [Colors.blue, Colors.blueAccent],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Resueltos',
                                value: resolvedReports.toString(),
                                icon: Icons.check_circle,
                                color: Colors.green,
                                gradient: LinearGradient(
                                  colors: [Colors.green, Colors.greenAccent],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                );
              },
            ),

            // Reportes por tipo
            Text(
              'Reportes por Tipo',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _TypeStatsWidget(),
            
            const SizedBox(height: 24),

            // Actividad reciente
            Text(
              'Actividad Reciente',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _RecentActivityWidget(colorScheme: colorScheme, textTheme: textTheme),
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar una tarjeta de estadística
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Gradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onPrimary, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para mostrar estadísticas por tipo
class _TypeStatsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        final typeCounts = <String, int>{};
        
        for (final doc in reports) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'otro';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        final types = ['robo', 'incendio', 'emergencia', 'accidente', 'otro'];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: types.map<Widget>((type) {
              final count = typeCounts[type] ?? 0;
              final label = _getTypeLabel(type);
              final icon = _getTypeIcon(type);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'robo':
        return 'Robo';
      case 'incendio':
        return 'Incendio';
      case 'emergencia':
        return 'Emergencia';
      case 'accidente':
        return 'Accidente';
      default:
        return 'Otro';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'robo':
        return Icons.security;
      case 'incendio':
        return Icons.local_fire_department;
      case 'emergencia':
        return Icons.warning;
      case 'accidente':
        return Icons.car_crash;
      default:
        return Icons.report;
    }
  }
}

// Widget para mostrar actividad reciente
class _RecentActivityWidget extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RecentActivityWidget({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allReports = snapshot.data?.docs ?? [];
        if (allReports.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No hay actividad reciente',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        // Ordenar por fecha (manejar tanto String como Timestamp)
        final reports = List.from(allReports);
        reports.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          DateTime? aDate;
          DateTime? bDate;
          
          final aCreatedAt = aData['createdAt'];
          final bCreatedAt = bData['createdAt'];
          
          if (aCreatedAt is String) {
            aDate = DateTime.tryParse(aCreatedAt);
          } else if (aCreatedAt != null) {
            try {
              aDate = (aCreatedAt as dynamic).toDate();
            } catch (_) {
              aDate = DateTime.now();
            }
          } else {
            aDate = DateTime.now();
          }
          
          if (bCreatedAt is String) {
            bDate = DateTime.tryParse(bCreatedAt);
          } else if (bCreatedAt != null) {
            try {
              bDate = (bCreatedAt as dynamic).toDate();
            } catch (_) {
              bDate = DateTime.now();
            }
          } else {
            bDate = DateTime.now();
          }
          
          return (bDate ?? DateTime.now()).compareTo(aDate ?? DateTime.now());
        });
        
        // Limitar a 5
        final limitedReports = reports.take(5).toList();

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: limitedReports.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final doc = limitedReports[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'Sin título';
              final type = data['type'] as String? ?? 'otro';
              final createdAt = data['createdAt'];
              
              DateTime? date;
              if (createdAt != null) {
                if (createdAt is String) {
                  date = DateTime.tryParse(createdAt);
                } else {
                  try {
                    date = (createdAt as dynamic).toDate();
                  } catch (_) {
                    date = DateTime.now();
                  }
                }
              } else {
                date = DateTime.now();
              }
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    _getTypeIcon(type),
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(title, style: textTheme.bodyLarge),
                subtitle: Text(
                  date != null ? _formatDate(date) : 'Fecha desconocida',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'robo':
        return Icons.security;
      case 'incendio':
        return Icons.local_fire_department;
      case 'emergencia':
        return Icons.warning;
      case 'accidente':
        return Icons.car_crash;
      default:
        return Icons.report;
    }
  }
}

// Widget para mostrar acceso denegado
class _AccessDeniedWidget extends StatelessWidget {
  final String message;

  const _AccessDeniedWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Acceso Denegado',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

