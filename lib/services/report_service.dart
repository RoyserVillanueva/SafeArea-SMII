// 7.4. Mostrar reportes en orden cronologico
// 9.3 Implementación de selector de distancia
// 9.5. Guardar preferencias de filtro
// 10.2. Validar que solo el autor pueda modificar
// 10.4. Implementar eliminación con confirmación
// 6.5. Guardar reporte en Firestore
// 7.5. Implementar scroll infinito
// 16.3. Implementar gráfico de reportes por día
// 17.5. Registrar acciones en logs

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import 'notification_service.dart';
import 'location_service.dart';

class ReportService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedFilter = 'todos';
  String _selectedStatus = 'todos';

  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;
  String get selectedStatus => _selectedStatus;

  // 🔐 NUEVO: Constructor que carga los filtros guardados
  ReportService() {
    _loadSavedFilters();
  }

  // 🔐 NUEVO: Cargar filtros desde SharedPreferences
  // 9.5 Persistencia de Filtros
  Future<void> _loadSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilter = prefs.getString('selected_filter');
      final savedStatus = prefs.getString('selected_status');
      
      if (savedFilter != null && savedFilter.isNotEmpty) {
        _selectedFilter = savedFilter;
      }
      if (savedStatus != null && savedStatus.isNotEmpty) {
        _selectedStatus = savedStatus;
      }
      notifyListeners();
      debugPrint('📦 Filtros cargados: filter=$_selectedFilter, status=$_selectedStatus');
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }

  // RF-05: Crear reporte
  Future<String?> createReport({
    required String userId,
    required String type,
    required String title,
    required String description,
    required String location,
    double? latitude,
    double? longitude,
    List<String>? images,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final docRef = _firestore.collection('reports').doc();
      final now = DateTime.now();
      await docRef.set({
        'id': docRef.id,
        'userId': userId,
        'type': type,
        'title': title,
        'description': description,
        'location': location,
        'status': 'activo',
        'images': images ?? <String>[],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'verifiedBy': <String>[],
        'isActive': true,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      NotificationService.sendNewReportNotification(
        reportId: docRef.id,
        reportTitle: title,
        reportType: type,
        creatorUserId: userId,
        imageUrl: (images?.isNotEmpty ?? false) ? images!.first : null,
      );

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Error al crear reporte: $e';
    }
  }

  // RF-08: Editar reporte
  Future<String?> updateReport(Report report) async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final hoursSinceCreation = now.difference(report.createdAt).inHours;
      if (hoursSinceCreation > 24) {
        _isLoading = false;
        notifyListeners();
        return 'Solo puedes editar el reporte dentro de las primeras 24 horas de creado';
      }

      final updatedReport = report.copyWith(updatedAt: now);

      await _firestore.collection('reports').doc(report.id).update({
        ...updatedReport.toMap(),
        'updatedAt': now.toIso8601String(),
      });

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Error al actualizar reporte: $e';
    }
  }

  // RF-07: Cambiar estado
  Future<String?> changeReportStatus(String reportId, String newStatus) async {
    try {
      final reportDoc = await _firestore.collection('reports').doc(reportId).get();
      if (reportDoc.exists) {
        final data = reportDoc.data()!;
        final report = Report.fromMap(data);
        
        NotificationService.sendReportStatusChangeNotification(
          reportId: reportId,
          reportTitle: report.title,
          newStatus: newStatus,
          ownerUserId: report.userId,
          imageUrl: report.images.isNotEmpty ? report.images.first : null,
        );
      }

      final now = DateTime.now();
      await _firestore.collection('reports').doc(reportId).update({
        'status': newStatus,
        'updatedAt': now.toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Error al cambiar estado: $e';
    }
  }

  // RF-09: Obtener reportes con filtros
  Stream<QuerySnapshot> getReports({String? typeFilter, String? statusFilter}) {
    final reportsRef = _firestore.collection('reports');
    
    Query query = reportsRef.where('isActive', isEqualTo: true);

    bool hasTypeFilter = typeFilter != null && typeFilter != 'todos';
    bool hasStatusFilter = statusFilter != null && statusFilter != 'todos';

    if (hasTypeFilter && hasStatusFilter) {
      query = query
          .where('type', isEqualTo: typeFilter)
          .where('status', isEqualTo: statusFilter);
    } else if (hasTypeFilter) {
      query = query.where('type', isEqualTo: typeFilter);
    } else if (hasStatusFilter) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // Obtener reportes de un usuario específico
  Stream<QuerySnapshot> getUserReports(String userId) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Obtener un reporte por ID
  Future<Report?> getReportById(String reportId) async {
    try {
      final doc = await _firestore.collection('reports').doc(reportId).get();
      if (doc.exists) {
        return Report.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting report: $e');
      return null;
    }
  }

  // 🔐 MEJORADO: Cambiar filtros con persistencia
  void setFilter(String filter) async {
    _selectedFilter = filter;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_filter', filter);
    notifyListeners();
    debugPrint('📦 Filtro guardado: filter=$filter');
  }

  // 🔐 MEJORADO: Cambiar filtro de estado con persistencia
  void setStatusFilter(String status) async {
    _selectedStatus = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_status', status);
    notifyListeners();
    debugPrint('📦 Estado guardado: status=$status');
  }

  // 🔐 NUEVO: Método para limpiar filtros guardados
  Future<void> clearSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_filter');
    await prefs.remove('selected_status');
    _selectedFilter = 'todos';
    _selectedStatus = 'todos';
    notifyListeners();
    debugPrint('📦 Filtros limpiados');
  }

  // RF-17: Eliminación lógica de reportes
  Future<String?> softDeleteReport(String reportId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('reports').doc(reportId).update({
        'isActive': false,
        'updatedAt': now.toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Error al eliminar reporte: $e';
    }
  }

  // Utilidad: crear reportes de prueba para un usuario
  Future<String?> seedSampleReports({required String userId}) async {
    try {
      const types = ['robo', 'incendio', 'emergencia', 'accidente', 'otro'];
      for (final type in types) {
        final docRef = _firestore.collection('reports').doc();
        final now = DateTime.now();
        final report = Report(
          id: docRef.id,
          userId: userId,
          type: type,
          title: 'Reporte de $type en Tacna',
          description: 'Reporte de prueba tipo $type generado para pruebas.',
          location: 'Tacna, Tacna, Tacna',
          status: 'activo',
          images: [],
          createdAt: now,
          updatedAt: now,
          verifiedBy: [],
          isActive: true,
        );
        await docRef.set(report.toMap());
      }
      return null;
    } catch (e) {
      return 'Error al sembrar reportes: $e';
    }
  }
  // 9.3 Distancia
      // 🔐 NUEVO: Filtrar reportes por distancia (después de obtenerlos)
    Future<List<Report>> filterReportsByDistance({
      required List<Report> reports,
      required double? maxDistanceKm,
    }) async {
      // Si no hay filtro de distancia, devolver todos
      if (maxDistanceKm == null || maxDistanceKm <= 0) {
        return reports;
      }

      // Obtener ubicación actual del usuario
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        debugPrint('⚠️ No se pudo obtener ubicación para filtrar por distancia');
        return reports;
      }

      final userLat = position.latitude;
      final userLon = position.longitude;

      // Filtrar reportes por distancia
      final filteredReports = reports.where((report) {
        if (report.latitude == null || report.longitude == null) {
          return false; // Reportes sin coordenadas no se incluyen
        }
        
        return LocationService.isWithinRadius(
          userLat, userLon,
          report.latitude!, report.longitude!,
          maxDistanceKm,
        );
      }).toList();

      debugPrint('📍 Filtro de distancia: ${reports.length} → ${filteredReports.length} reportes (radio: ${maxDistanceKm}km)');
      
      return filteredReports;
    }

    /// Verificar si un reporte está dentro del radio de distancia del usuario
    Future<bool> isReportWithinRadius(Report report, double maxDistanceKm) async {
      if (maxDistanceKm == null || maxDistanceKm <= 0) return true;
      if (report.latitude == null || report.longitude == null) return false;
      
      final position = await LocationService.getCurrentLocation();
      if (position == null) return true; // Si no hay ubicación, mostrar todos
      
      return LocationService.isWithinRadius(
        position.latitude, position.longitude,
        report.latitude!, report.longitude!,
        maxDistanceKm,
      );
    }
}