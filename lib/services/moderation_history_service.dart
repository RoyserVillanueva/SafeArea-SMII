// 18.6 Registrar historial de moderación
// moderation_history_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationHistoryService {
  static Future<void> recordAction({
    required String reportId,
    required String action,
    required String moderatorId,
    String? reason,
  }) async {
    await FirebaseFirestore.instance.collection('moderation_history').add({
      'reportId': reportId,
      'action': action,
      'moderatorId': moderatorId,
      'reason': reason ?? '',
      'date': DateTime.now().toIso8601String(),
    });
  }
}