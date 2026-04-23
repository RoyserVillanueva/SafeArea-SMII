import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handler para notificaciones cuando la app está en segundo plano
// NOTA: Este handler solo se usa en Android/iOS, no en Web
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
  debugPrint('Image URL: ${message.data['image'] ?? message.data['image_url']}');
  
  // Solo mostrar notificaciones locales en Android/iOS (no en Web)
  if (!kIsWeb) {
    // Mostrar notificación local cuando la app está en segundo plano
    final FlutterLocalNotificationsPlugin localNotifications = 
        FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await localNotifications.initialize(initSettings);
    
    final notification = message.notification;
    if (notification != null) {
      const androidDetails = AndroidNotificationDetails(
        'safearea_channel',
        'SafeArea Notificaciones',
        channelDescription: 'Notificaciones de reportes y mensajes',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final payload = '${message.data['type'] ?? 'general'}|${message.data['id'] ?? ''}';
      
      await localNotifications.show(
        message.hashCode,
        notification.title ?? 'Nueva notificación',
        notification.body ?? '',
        details,
        payload: payload,
      );
    }
  }
  
  // En Web, Firebase Messaging maneja las notificaciones automáticamente
  // Aquí puedes procesar la notificación, actualizar base de datos local, etc.
}

