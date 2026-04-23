import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import 'notification_service.dart';

class ReportService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedFilter = 'todos';
  String _selectedStatus = 'todos';

  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;
  String get selectedStatus => _selectedStatus;

  // RF-05: Crear reporte
  Future<String?> createReport({
    required String userId,
    required String type,
    required String title,
    required String description,
    required String location,
    double? latitude,
    double? longitude,
    List<String>? images, // RF-11: Soporte para imágenes
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final docRef = _firestore.collection('reports').doc();
      // Usar timestamp ISO para evitar problemas con índices
      final now = DateTime.now();
      await docRef.set({
        'id': docRef.id,
        'userId': userId,
        'type': type,
        'title': title,
        'description': description,
        'location': location,
        'status': 'activo',
        'images': images ?? <String>[], // RF-11: URLs de imágenes
        'createdAt': now.toIso8601String(), // Guardar como String ISO para evitar problemas con índices
        'updatedAt': now.toIso8601String(),
        'verifiedBy': <String>[],
        'isActive': true,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      // Enviar notificación automática a todos los usuarios
      NotificationService.sendNewReportNotification(
        reportId: docRef.id,
        reportTitle: title,
        reportType: type,
        creatorUserId: userId,
        imageUrl: (images?.isNotEmpty ?? false) ? images!.first : null, // RF-11: Primera imagen como preview
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

      // RN-03: Solo permitir edición dentro de las primeras 24 horas
      final now = DateTime.now();
      final hoursSinceCreation = now.difference(report.createdAt).inHours;
      if (hoursSinceCreation > 24) {
        _isLoading = false;
        notifyListeners();
        return 'Solo puedes editar el reporte dentro de las primeras 24 horas de creado';
      }

      final updatedReport = report.copyWith(
        updatedAt: now,
      );

      // Actualizar con formato ISO para mantener consistencia
      await _firestore.collection('reports').doc(report.id).update({
        ...updatedReport.toMap(),
        'updatedAt': now.toIso8601String(), // Asegurar formato ISO
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
      // Obtener el reporte para enviar notificación al dueño
      final reportDoc = await _firestore.collection('reports').doc(reportId).get();
      if (reportDoc.exists) {
        final data = reportDoc.data()!;
        final report = Report.fromMap(data);
        
        // Enviar notificación al dueño del reporte
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
        'updatedAt': now.toIso8601String(), // Mantener formato ISO
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

    // Aplicar filtros
    // Nota: Si usamos múltiples where + orderBy, Firestore puede requerir índice compuesto
    // Para evitar esto, aplicamos solo un filtro a la vez si ambos están presentes
    bool hasTypeFilter = typeFilter != null && typeFilter != 'todos';
    bool hasStatusFilter = statusFilter != null && statusFilter != 'todos';

    if (hasTypeFilter && hasStatusFilter) {
      // Si hay ambos filtros, aplicar solo uno y filtrar el otro en el cliente
      // Aplicamos typeFilter (más específico) y filtramos status en el cliente
      query = query.where('type', isEqualTo: typeFilter);
    } else if (hasTypeFilter) {
      query = query.where('type', isEqualTo: typeFilter);
    } else if (hasStatusFilter) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    // Ordenar por createdAt (como String ISO funciona bien)
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

  // Cambiar filtros
  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _selectedStatus = status;
    notifyListeners();
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
}