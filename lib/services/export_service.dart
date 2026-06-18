// lib/services/export_service.dart
// 16.6. Exportar datos a CSV (Solo Mobile)

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  static Future<void> exportReportsToCSV({
    required List<QueryDocumentSnapshot> reports,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    try {
      final List<List<String>> rows = [
        ['ID', 'Título', 'Tipo', 'Estado', 'Fecha', 'Ubicación', 'Usuario'],
      ];

      for (final doc in reports) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'];
        String? dateStr;

        if (createdAt != null) {
          if (createdAt is String) {
            dateStr = DateTime.tryParse(createdAt)?.toLocal().toString() ?? createdAt;
          } else {
            try {
              dateStr = (createdAt as dynamic).toDate().toLocal().toString();
            } catch (_) {
              dateStr = createdAt.toString();
            }
          }
        }

        rows.add([
          doc.id,
          data['title'] ?? '',
          data['type'] ?? '',
          data['status'] ?? '',
          dateStr ?? '',
          data['location'] ?? '',
          data['userId'] ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);

      final tempDir = Directory.systemTemp;
      final fileName = 'reportes_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csv, encoding: utf8);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Reportes SafeArea - ${_getDateRangeLabel(startDate, endDate)}',
      );

      debugPrint('✅ CSV exportado correctamente');
    } catch (e) {
      debugPrint('❌ Error exportando CSV: $e');
      rethrow;
    }
  }

  static String _getDateRangeLabel(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) return 'Desde siempre';
    return '${startDate!.toLocal().toString().split(' ')[0]} al ${endDate!.toLocal().toString().split(' ')[0]}';
  }
}