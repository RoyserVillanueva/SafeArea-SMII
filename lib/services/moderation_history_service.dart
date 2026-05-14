// moderation_history_service.dart
class ModerationHistoryService {
  // Simulamos una base de datos local temporal
  static final List<Map<String, dynamic>> _history = [];

  // Método para registrar una acción en el historial
  static void recordAction({
    required String reportId, 
    required String action, 
    required String moderatorId
  }) {
    final newEntry = {
      'reportId': reportId,
      'action': action,
      'date': DateTime.now(),
      'moderatorId': moderatorId,
    };
    
    _history.add(newEntry);
    
    // TODO: Aquí iría la conexión para guardarlo en la base de datos (ej. SQL Server o Firebase)
    print('Historial guardado: Acción "$action" en el reporte $reportId por $moderatorId');
  }

  // Método para obtener el historial
  static List<Map<String, dynamic>> getHistory() {
    return _history;
  }
}