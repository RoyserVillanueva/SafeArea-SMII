// 15.5. Filtrar notificaciones según preferencias

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  // Tarea 14.5: Guardar token para recibir mensajes
  Future<void> saveToken(String userId) async {
    String? token = await FirebaseMessaging.instance.getToken();
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmToken': token,
    });
  }

  // Tarea 14.4: Lógica base para reportes cercanos
  void notifyNearReport(double lat, double lng) {
    print("Calculando radio de 500m para reporte en: $lat, $lng");
  }
}
