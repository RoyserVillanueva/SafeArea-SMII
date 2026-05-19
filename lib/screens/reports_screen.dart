// 7.4. Mostrar reportes en orden cronologico
// 9.5. Guardar preferencias de filtro
// 10.5. Actualizar lista tras cambios
// 7.5. Implementar scroll infinito

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';
import '../widgets/report_card.dart';
import 'add_report_screen.dart';
import 'report_detail_screen.dart';
import '../widgets/filter_chip.dart'; 
import '../services/location_service.dart'; // 🔐 NUEVO: Import para filtro de distancia

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // 9.3 Implementación de seleccion de distancia
  // Variable para la distancia seleccionada
  double? _selectedDistance; // null = sin filtro, valor en km
  
  // Estado para mostrar loading durante el filtrado por distancia
  bool _isFilteringByDistance = false;
  
  // Lista de reportes después del filtro de distancia
  List<Report> _filteredReportsByDistance = [];
  
  final List<String> typeFilters = ['todos', 'robo', 'incendio', 'emergencia', 'accidente', 'otro'];
  final List<String> statusFilters = ['todos', 'activo', 'en_proceso', 'resuelto'];
  
  // 🔐 NUEVO: Variables para scroll infinito
  // 7.5 Implementar scroll infinito
  final ScrollController _scrollController = ScrollController();
  final List<Report> _reports = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadInitialReports();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreReports();
    }
  }

  Future<void> _loadInitialReports() async {
    setState(() {
      // No marcar _isLoading aquí: _loadMoreReports controla su propio estado.
      _reports.clear();
      _lastDocument = null;
      _hasMore = true;
      _filteredReportsByDistance.clear(); // 🔐 Limpiar filtro de distancia
    });

    await _loadMoreReports();

    setState(() {
      _isInitialLoad = false;
    });
  }

  Future<void> _loadMoreReports() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);
    
    try {
      final reportService = Provider.of<ReportService>(context, listen: false);
      
      // Construir query base
      Query query = FirebaseFirestore.instance
          .collection('reports')
          .where('isActive', isEqualTo: true);
      
      // Aplicar filtros
      if (reportService.selectedFilter != 'todos') {
        query = query.where('type', isEqualTo: reportService.selectedFilter);
      }
      if (reportService.selectedStatus != 'todos') {
        query = query.where('status', isEqualTo: reportService.selectedStatus);
      }
      
      // Ordenar y limitar
      query = query.orderBy('createdAt', descending: true).limit(20);
      
      // Paginación
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastDocument = snapshot.docs.last;
        final newReports = snapshot.docs.map((doc) => 
          Report.fromMap(doc.data() as Map<String, dynamic>)).toList();
        
        // 🔐 NUEVO: Aplicar filtro de distancia si está seleccionado
        if (_selectedDistance != null && _selectedDistance! > 0) {
          final userPosition = await LocationService.getCurrentLocation();
          if (userPosition != null) {
            final filteredNewReports = newReports.where((report) {
              if (report.latitude == null || report.longitude == null) return false;
              return LocationService.isWithinRadius(
                userPosition.latitude, userPosition.longitude,
                report.latitude!, report.longitude!,
                _selectedDistance!,
              );
            }).toList();
            
            setState(() {
              _reports.addAll(filteredNewReports);
            });
          } else {
            // Si no se puede obtener ubicación, agregar todos (sin filtro)
            setState(() {
              _reports.addAll(newReports);
            });
          }
        } else {
          setState(() {
            _reports.addAll(newReports);
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando reportes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reportes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Refrescar cuando cambian los filtros
  void _onFiltersChanged() {
    _loadInitialReports();
  }

  @override
  Widget build(BuildContext context) {
    final reportService = Provider.of<ReportService>(context);
    final auth = Provider.of<AuthService>(context);
    final isAdmin = auth.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
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
            onPressed: () => _showFiltersSheet(onFiltersChanged: _onFiltersChanged),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialReports,
        child: _buildBody(),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isInitialLoad && _reports.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🔐 NUEVO: Mostrar indicador de filtro de distancia activo
    if (_selectedDistance != null && _selectedDistance! > 0) {
      return Column(
        children: [
          // Chip indicador de filtro activo
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Mostrando reportes dentro de ${_selectedDistance!.toStringAsFixed(0)} km',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDistance = null;
                      _loadInitialReports();
                    });
                  },
                  child: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Lista de reportes
          Expanded(
            child: _buildReportList(),
          ),
        ],
      );
    }

    return _buildReportList();
  }

  // 🔐 NUEVO: Widget separado para la lista de reportes
  Widget _buildReportList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_reports.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No hay reportes',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu primer reporte usando el botón +',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _reports.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _reports.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final report = _reports[index];
        final auth = Provider.of<AuthService>(context);
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
      },
    );
  }

  Widget _buildFAB() {
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
  }

  void _showFiltersSheet({required VoidCallback onFiltersChanged}) {
    final reportService = Provider.of<ReportService>(context, listen: false);
    // 9.3 Implementación de distancia
    // Variable local para la distancia seleccionada (no afecta al servicio principal)
    double? tempSelectedDistance = _selectedDistance;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Filtro por Tipo de Incidente
                    const Text('Tipo de Incidente:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Filtro por Estado
                    const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    
                    // 🔐 NUEVO: Selector de Distancia (9.3)
                    const SizedBox(height: 16),
                    const Text('Distancia:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDistanceChipModal('Sin filtro', null, tempSelectedDistance, (value) {
                          setModalState(() {
                            tempSelectedDistance = value;
                          });
                        }),
                        _buildDistanceChipModal('1 km', 1, tempSelectedDistance, (value) {
                          setModalState(() {
                            tempSelectedDistance = value;
                          });
                        }),
                        _buildDistanceChipModal('5 km', 5, tempSelectedDistance, (value) {
                          setModalState(() {
                            tempSelectedDistance = value;
                          });
                        }),
                        _buildDistanceChipModal('10 km', 10, tempSelectedDistance, (value) {
                          setModalState(() {
                            tempSelectedDistance = value;
                          });
                        }),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Guardar la distancia seleccionada antes de cerrar
                          _selectedDistance = tempSelectedDistance;
                          Navigator.pop(context);
                          onFiltersChanged();
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔐 NUEVO: Método auxiliar para construir los chips de distancia
  Widget _buildDistanceChipModal(String label, double? distance, double? currentSelected, Function(double?) onSelected) {
    final isSelected = currentSelected == distance;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(distance),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 0 : 1,
        ),
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}