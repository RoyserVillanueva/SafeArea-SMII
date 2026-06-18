// 3.4. Probar el flujo del dashboard y redirecciones
// 16.3. Implementar gráfico de reportes por día con selector de fechas
// 16.5. Calcular usuarios activos diarios
// 16.6. Exportar datos a CSV

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import 'heatmap_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ==================== CONTROL DE FECHAS ====================
  
  // null = "Desde siempre" (sin filtro de fechas)
  DateTime? _startDate = null;
  DateTime? _endDate = null;
  
  final List<Map<String, dynamic>> _dateRangeOptions = [
    {'label': 'Desde siempre', 'days': null, 'isAlways': true},
    {'label': 'Últimos 7 días', 'days': 7, 'isAlways': false},
    {'label': 'Últimos 14 días', 'days': 14, 'isAlways': false},
    {'label': 'Últimos 30 días', 'days': 30, 'isAlways': false},
    {'label': 'Últimos 90 días', 'days': 90, 'isAlways': false},
    {'label': 'Personalizado', 'days': null, 'isAlways': false},
  ];
  
  String _selectedRangeLabel = 'Desde siempre';

  // ==================== MÉTODOS DE FECHAS ====================

  void _updateDateRange(int? days) {
    setState(() {
      if (days == null) {
        _startDate = null;
        _endDate = null;
      } else {
        _startDate = DateTime.now().subtract(Duration(days: days));
        _endDate = DateTime.now();
      }
    });
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _endDate ?? DateTime.now(),
      ),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedRangeLabel = 'Personalizado';
      });
    }
  }

  void _showDateRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Dashboard por Fechas'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._dateRangeOptions.map((option) {
                final isSelected = _selectedRangeLabel == option['label'];
                return RadioListTile<String>(
                  title: Text(option['label']),
                  value: option['label'],
                  groupValue: _selectedRangeLabel,
                  onChanged: (value) {
                    if (option['isAlways'] == true) {
                      _updateDateRange(null);
                      setState(() {
                        _selectedRangeLabel = option['label'];
                      });
                      Navigator.pop(context);
                    } else if (option['days'] != null) {
                      _updateDateRange(option['days']);
                      setState(() {
                        _selectedRangeLabel = option['label'];
                      });
                      Navigator.pop(context);
                    } else {
                      Navigator.pop(context);
                      _selectCustomDateRange();
                    }
                  },
                );
              }).toList(),
              
              const Divider(),
              
              // Mostrar rango actual
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Rango actual'),
                subtitle: Text(
                  _startDate == null && _endDate == null
                      ? 'Desde siempre (todos los reportes)'
                      : '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context);
                    _selectCustomDateRange();
                  },
                ),
              ),
            ],
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
  }

  bool _isDateInRange(DateTime? date) {
    if (date == null) return false;
    if (_startDate == null && _endDate == null) return true;
    return date.isAfter(_startDate!.subtract(const Duration(days: 1))) && 
           date.isBefore(_endDate!.add(const Duration(days: 1)));
  }

  String _getDateRangeLabel() {
    if (_startDate == null && _endDate == null) {
      return 'Desde siempre';
    }
    return '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
  }

  // ==================== EXPORTAR A CSV ====================

  Future<void> _exportReports() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Exportando reportes...'),
            ],
          ),
        ),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('isActive', isEqualTo: true)
          .get();

      final reports = snapshot.docs;

      await ExportService.exportReportsToCSV(
        reports: reports,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reportes exportados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filtrar dashboard por fechas',
            onPressed: _showDateRangeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar reportes a CSV',
            onPressed: _exportReports,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== INDICADOR DE RANGO DE FECHAS ====================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_startDate == null && _endDate == null 
                      ? Icons.access_time_filled 
                      : Icons.calendar_today, 
                      size: 20, 
                      color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Filtro: ${_getDateRangeLabel()}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Restablecer a "Desde siempre"',
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _selectedRangeLabel = 'Desde siempre';
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // ==================== ESTADÍSTICAS ====================
            Text(
              'Resumen General',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _BuildStatsSection(
              startDate: _startDate,
              endDate: _endDate,
              isDateInRange: _isDateInRange,
            ),

            const SizedBox(height: 24),

            // ==================== USUARIOS ACTIVOS ====================
            Text(
              'Usuarios Activos',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _ActiveUsersWidget(
              startDate: _startDate,
              endDate: _endDate,
              isDateInRange: _isDateInRange,
            ),

            const SizedBox(height: 24),

            // ==================== REPORTES POR TIPO ====================
            Text(
              'Reportes por Tipo',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _TypeStatsWidget(
              startDate: _startDate,
              endDate: _endDate,
              isDateInRange: _isDateInRange,
            ),
            
            const SizedBox(height: 24),

            // ==================== GRÁFICO DE REPORTES POR DÍA ====================
            Text(
              'Reportes por Día',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _ReportsByDayChart(
              startDate: _startDate,
              endDate: _endDate,
              isDateInRange: _isDateInRange,
            ),

            const SizedBox(height: 24),

            // ==================== MAPA DE CALOR ====================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.1),
                    colorScheme.tertiary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.heat_pump,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mapa de Calor',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Visualiza la concentración de incidentes por zona',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HeatmapScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Ver Mapa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================== ACTIVIDAD RECIENTE ====================
            Text(
              'Actividad Reciente',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _RecentActivityWidget(
              startDate: _startDate,
              endDate: _endDate,
              isDateInRange: _isDateInRange,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET: ESTADÍSTICAS (CON FILTRO DE FECHAS)
// ============================================================

class _BuildStatsSection extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool Function(DateTime?) isDateInRange;

  const _BuildStatsSection({
    required this.startDate,
    required this.endDate,
    required this.isDateInRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<QuerySnapshot>(
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
            final allReports = reportsSnapshot.data?.docs ?? [];
            final filteredReports = allReports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'];
              if (createdAt == null) return false;
              
              DateTime? reportDate;
              if (createdAt is String) {
                reportDate = DateTime.tryParse(createdAt);
              } else {
                try {
                  reportDate = (createdAt as dynamic).toDate();
                } catch (_) {}
              }
              
              return isDateInRange(reportDate);
            }).toList();

            final totalReports = filteredReports.length;
            final totalUsers = usersSnapshot.data?.docs.length ?? 0;
            
            int activeReports = 0;
            int inProcessReports = 0;
            int resolvedReports = 0;
            
            for (final doc in filteredReports) {
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
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================
// WIDGET: TARJETA DE ESTADÍSTICA
// ============================================================

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

// ============================================================
// WIDGET: USUARIOS ACTIVOS DIARIOS
// ============================================================

class _ActiveUsersWidget extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool Function(DateTime?) isDateInRange;

  const _ActiveUsersWidget({
    required this.startDate,
    required this.endDate,
    required this.isDateInRange,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
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
            final allUsers = usersSnapshot.data?.docs ?? [];
            
            final allReports = reportsSnapshot.data?.docs ?? [];
            final filteredReports = allReports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'];
              if (createdAt == null) return false;
              
              DateTime? reportDate;
              if (createdAt is String) {
                reportDate = DateTime.tryParse(createdAt);
              } else {
                try {
                  reportDate = (createdAt as dynamic).toDate();
                } catch (_) {}
              }
              
              return isDateInRange(reportDate);
            }).toList();

            final activeUserIds = filteredReports
                .map((doc) => (doc.data() as Map<String, dynamic>)['userId'] as String?)
                .where((id) => id != null)
                .toSet()
                .cast<String>()
                .toList();

            final now = DateTime.now();
            final daysToShow = startDate == null && endDate == null ? 7 : 
                (endDate!.difference(startDate!).inDays + 1 > 30 ? 30 : endDate!.difference(startDate!).inDays + 1);
            
            final dates = List.generate(daysToShow, (index) {
              return now.subtract(Duration(days: (daysToShow - 1) - index));
            });

            final dailyActiveUsers = <String, int>{};
            for (final date in dates) {
              final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              dailyActiveUsers[key] = 0;
            }

            for (final doc in filteredReports) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'];
              final userId = data['userId'] as String?;
              if (userId == null) continue;
              
              DateTime? reportDate;
              if (createdAt is String) {
                reportDate = DateTime.tryParse(createdAt);
              } else {
                try {
                  reportDate = (createdAt as dynamic).toDate();
                } catch (_) {}
              }
              
              if (reportDate != null) {
                final key = '${reportDate.year}-${reportDate.month.toString().padLeft(2, '0')}-${reportDate.day.toString().padLeft(2, '0')}';
                final dayKey = '${key}_$userId';
                if (!dailyActiveUsers.containsKey(dayKey)) {
                  dailyActiveUsers[key] = (dailyActiveUsers[key] ?? 0) + 1;
                  dailyActiveUsers[dayKey] = 1;
                }
              }
            }

            final List<BarChartGroupData> barGroups = [];
            final List<String> labels = [];
            int maxY = 0;

            for (int i = 0; i < dates.length; i++) {
              final date = dates[i];
              final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final count = dailyActiveUsers[key] ?? 0;
              barGroups.add(
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: count.toDouble(),
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
              labels.add('${date.day}/${date.month}');
              if (count > maxY) maxY = count;
            }

            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '👥 Usuarios activos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: ${activeUserIds.length} usuarios',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (maxY + 1).toDouble(),
                        barGroups: barGroups,
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: labels.length > 15 ? 2 : 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labels[index],
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// WIDGET: ESTADÍSTICAS POR TIPO (CON FILTRO DE FECHAS)
// ============================================================

class _TypeStatsWidget extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool Function(DateTime?) isDateInRange;

  const _TypeStatsWidget({
    required this.startDate,
    required this.endDate,
    required this.isDateInRange,
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

        final allReports = snapshot.data!.docs;
        
        final filteredReports = allReports.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'];
          if (createdAt == null) return false;
          
          DateTime? reportDate;
          if (createdAt is String) {
            reportDate = DateTime.tryParse(createdAt);
          } else {
            try {
              reportDate = (createdAt as dynamic).toDate();
            } catch (_) {}
          }
          
          return isDateInRange(reportDate);
        }).toList();

        final typeCounts = <String, int>{};
        
        for (final doc in filteredReports) {
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
      case 'robo': return 'Robo';
      case 'incendio': return 'Incendio';
      case 'emergencia': return 'Emergencia';
      case 'accidente': return 'Accidente';
      default: return 'Otro';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'robo': return Icons.security;
      case 'incendio': return Icons.local_fire_department;
      case 'emergencia': return Icons.warning;
      case 'accidente': return Icons.car_crash;
      default: return Icons.report;
    }
  }
}

// ============================================================
// WIDGET: GRÁFICO DE REPORTES POR DÍA (CON FILTRO DE FECHAS)
// ============================================================

class _ReportsByDayChart extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool Function(DateTime?) isDateInRange;

  const _ReportsByDayChart({
    required this.startDate,
    required this.endDate,
    required this.isDateInRange,
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
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final allReports = snapshot.data!.docs;
        
        final filteredReports = allReports.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'];
          if (createdAt == null) return false;
          
          DateTime? reportDate;
          if (createdAt is String) {
            reportDate = DateTime.tryParse(createdAt);
          } else {
            try {
              reportDate = (createdAt as dynamic).toDate();
            } catch (_) {}
          }
          
          return isDateInRange(reportDate);
        }).toList();

        late DateTime effectiveStartDate;
        late DateTime effectiveEndDate;
        
        if (startDate == null && endDate == null) {
          effectiveEndDate = DateTime.now();
          effectiveStartDate = effectiveEndDate.subtract(const Duration(days: 30));
        } else {
          effectiveStartDate = startDate!;
          effectiveEndDate = endDate!;
        }

        final daysDifference = effectiveEndDate.difference(effectiveStartDate).inDays + 1;
        final daysToShow = daysDifference > 30 ? 30 : daysDifference;
        
        final dates = List.generate(daysToShow, (index) {
          return effectiveStartDate.add(Duration(days: index));
        });

        final Map<String, int> dailyCounts = {};
        
        for (final date in dates) {
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          dailyCounts[key] = 0;
        }

        for (final doc in filteredReports) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'];
          DateTime? reportDate;
          
          if (createdAt != null) {
            if (createdAt is String) {
              reportDate = DateTime.tryParse(createdAt);
            } else {
              try {
                reportDate = (createdAt as dynamic).toDate();
              } catch (_) {}
            }
          }
          
          if (reportDate != null) {
            final key = '${reportDate.year}-${reportDate.month.toString().padLeft(2, '0')}-${reportDate.day.toString().padLeft(2, '0')}';
            if (dailyCounts.containsKey(key)) {
              dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
            }
          }
        }

        final List<FlSpot> spots = [];
        final List<String> labels = [];
        int maxY = 0;
        
        for (int i = 0; i < dates.length; i++) {
          final date = dates[i];
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final count = dailyCounts[key] ?? 0;
          spots.add(FlSpot(i.toDouble(), count.toDouble()));
          labels.add('${date.day}/${date.month}');
          if (count > maxY) maxY = count;
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reportes creados',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${spots.fold(0, (sum, spot) => sum + spot.y.toInt())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: colorScheme.outlineVariant,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: daysToShow > 15 ? 2 : 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < labels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  labels[index],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY > 0 ? maxY.toDouble() + 1 : 5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: AppTheme.primaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppTheme.primaryColor,
                              strokeWidth: 2,
                              strokeColor: colorScheme.surface,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((touchedSpot) {
                            final spot = touchedSpot;
                            final index = spot.spotIndex;
                            return LineTooltipItem(
                              '${labels[index]}: ${spot.y.toInt()} reportes',
                              TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// WIDGET: ACTIVIDAD RECIENTE (CON FILTRO DE FECHAS)
// ============================================================

class _RecentActivityWidget extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool Function(DateTime?) isDateInRange;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RecentActivityWidget({
    required this.startDate,
    required this.endDate,
    required this.isDateInRange,
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
        
        final filteredReports = allReports.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'];
          if (createdAt == null) return false;
          
          DateTime? reportDate;
          if (createdAt is String) {
            reportDate = DateTime.tryParse(createdAt);
          } else {
            try {
              reportDate = (createdAt as dynamic).toDate();
            } catch (_) {}
          }
          
          return isDateInRange(reportDate);
        }).toList();

        if (filteredReports.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                startDate == null && endDate == null
                    ? 'No hay reportes disponibles'
                    : 'No hay actividad en este rango',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final reports = List.from(filteredReports);
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
      case 'robo': return Icons.security;
      case 'incendio': return Icons.local_fire_department;
      case 'emergencia': return Icons.warning;
      case 'accidente': return Icons.car_crash;
      default: return Icons.report;
    }
  }
}

// ============================================================
// WIDGET: ACCESO DENEGADO
// ============================================================

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