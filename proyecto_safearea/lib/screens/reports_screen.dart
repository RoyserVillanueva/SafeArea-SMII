import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';
import '../widgets/report_card.dart';
import '../widgets/filter_chip.dart';
import 'add_report_screen.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final List<String> typeFilters = ['todos', 'robo', 'incendio', 'emergencia', 'accidente', 'otro'];
  final List<String> statusFilters = ['todos', 'activo', 'en_proceso', 'resuelto'];

  @override
  Widget build(BuildContext context) {
    final reportService = Provider.of<ReportService>(context);
    final auth = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reportes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          // RF-17: Solo administradores pueden usar herramientas de moderación/desarrollo
          if (isAdmin)
            IconButton(
              tooltip: 'Crear datos de prueba',
              icon: const Icon(Icons.cloud_upload),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sembrar datos de prueba'),
                    content: const Text('Se crearán 5 reportes (uno por tipo) con ubicación "Tacna, Tacna, Tacna". ¿Continuar?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (!context.mounted) return;
                  final err = await Provider.of<ReportService>(context, listen: false)
                      .seedSampleReports(userId: auth.currentUser!.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'Reportes de prueba creados')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
            onPressed: _showFiltersSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de reportes
          Expanded(
            child: StreamBuilder(
              stream: reportService.getReports(
                typeFilter: reportService.selectedFilter == 'todos' ? null : reportService.selectedFilter,
                statusFilter: reportService.selectedStatus == 'todos' ? null : reportService.selectedStatus,
              ),
              builder: (context, snapshot) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                final textTheme = theme.textTheme;

                if (snapshot.hasError) {
                  debugPrint('Error en StreamBuilder de reportes: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar reportes',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                            onPressed: () {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report, size: 64, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No hay reportes',
                          style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea tu primer reporte usando el botón +',
                          style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Procesar documentos y aplicar filtros adicionales si es necesario
                final docs = snapshot.data!.docs;
                final filteredDocs = <QueryDocumentSnapshot>[];
                
                for (final doc in docs) {
                  try {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) continue;
                    
                    // Si hay filtro de status pero no se aplicó en la query (porque hay múltiples filtros)
                    // filtrarlo aquí
                    if (reportService.selectedStatus != 'todos' && 
                        reportService.selectedFilter != 'todos') {
                      final status = data['status'] as String?;
                      if (status != reportService.selectedStatus) continue;
                    }
                    
                    filteredDocs.add(doc);
                  } catch (e) {
                    debugPrint('Error al procesar documento: $e');
                  }
                }

                // Ordenar por fecha (por si acaso no está ordenado)
                filteredDocs.sort((a, b) {
                  try {
                    final aDate = _parseDateFromDoc(a);
                    final bDate = _parseDateFromDoc(b);
                    return bDate.compareTo(aDate); // Descendente
                  } catch (e) {
                    return 0;
                  }
                });

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list, size: 64, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No hay reportes con estos filtros',
                          style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    try {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) return const SizedBox.shrink();
                      
                      final report = Report.fromMap(data);
                      
                      final isOwner = auth.currentUser?.id == report.userId;
                      return ReportCard(
                        report: report,
                        maskLocation: !isOwner,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportDetailScreen(report: report),
                            ),
                          );
                        },
                      );
                    } catch (e) {
                      debugPrint('Error al parsear reporte: $e');
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddReportScreen()),
                );
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Icon(Icons.add, color: colorScheme.onPrimary),
            ),
          );
        },
      ),
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final reportService = Provider.of<ReportService>(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros de reportes',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tipo de Incidente:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: typeFilters.map((filter) {
                    return FilterChipWidget(
                      label: filter == 'todos' ? 'Todos' : _capitalize(filter),
                      selected: reportService.selectedFilter == filter,
                      onSelected: () {
                        reportService.setFilter(filter);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Estado:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statusFilters.map((status) {
                    return FilterChipWidget(
                      label: status == 'todos' ? 'Todos' : _capitalize(status.replaceAll('_', ' ')),
                      selected: reportService.selectedStatus == status,
                      onSelected: () {
                        reportService.setStatusFilter(status);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Helper para parsear fecha desde un documento de Firestore
  DateTime _parseDateFromDoc(QueryDocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'];
      
      if (createdAt == null) return DateTime.now();
      
      // Si es Timestamp de Firestore
      if (createdAt is Timestamp) {
        return createdAt.toDate();
      }
      
      // Si es String
      if (createdAt is String) {
        return DateTime.parse(createdAt);
      }
      
      // Si tiene método toDate
      try {
        final toDate = createdAt.toDate;
        if (toDate is Function) {
          return toDate() as DateTime;
        }
      } catch (_) {}
      
      return DateTime.now();
    } catch (e) {
      debugPrint('Error parseando fecha: $e');
      return DateTime.now();
    }
  }
}