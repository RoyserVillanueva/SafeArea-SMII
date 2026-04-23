import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../screens/report_detail_screen.dart';
import '../screens/chat_screen.dart';
import '../models/report_model.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static GlobalKey<NavigatorState>? navigatorKey;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  Future<void> initialize(String userId) async {
    await _loadUserSettings();
    // Inicializar notificaciones locales (solo para Android/iOS)
    if (!kIsWeb) {
      await _initializeLocalNotifications();
    }

    // Solicitar permisos
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: _soundEnabled,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Obtener token FCM
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Escuchar nuevos tokens
      _messaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(userId).set({
          'fcmToken': newToken,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Manejar notificaciones en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        await _handleForegroundNotification(message);
      });

      // Manejar notificaciones cuando se abre la app desde notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationNavigation(message);
      });

      // Verificar si la app se abrió desde una notificación
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(initialMessage);
      }
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      debugPrint('NotificationService - settings: notifications=$_notificationsEnabled, sound=$_soundEnabled, vibration=$_vibrationEnabled');
    } catch (e) {
      debugPrint('Error cargando configuración de notificaciones (NotificationService): $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Solo inicializar para Android/iOS (no para web)
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Navegar cuando se hace clic en notificación local
        if (response.payload != null) {
          final data = response.payload!.split('|');
          if (data.length >= 2) {
            final type = data[0];
            final id = data[1];
            _navigateToScreen(type, id);
          }
        }
      },
    );

    // Crear el canal de notificación de Android con importancia alta (Android 8.0+)
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'safearea_channel', // id
        'SafeArea Notificaciones', // name
        description: 'Notificaciones de reportes y mensajes', // description
        importance: Importance.high, // Importancia ALTA
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Solicitar permisos Android 13+
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _handleForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Respetar configuración de notificaciones del usuario
    if (!_notificationsEnabled) {
      debugPrint('NotificationService: notificaciones desactivadas por el usuario. FCM no mostrado.');
      return;
    }

    // Extraer tipo e ID del payload para navegación
    final type = message.data['type'] ?? 'general';
    final id = message.data['id'] ?? '';
    final payload = '$type|$id';

    // Obtener URL de imagen si está disponible
    String? imageUrl = message.data['image'] ?? 
                       notification.android?.imageUrl ?? 
                       message.data['image_url'];

    // Manejar notificaciones según la plataforma
    if (kIsWeb) {
      // Para web: usar la API de notificaciones del navegador
      await _showWebNotification(
        title: notification.title ?? 'Nueva notificación',
        body: notification.body ?? '',
        imageUrl: imageUrl,
        payload: payload,
      );
    } else {
      // Para Android/iOS: usar flutter_local_notifications
      // Preparar detalles de Android (la imagen se muestra en el diálogo)
      final androidDetails = AndroidNotificationDetails(
        'safearea_channel',
        'SafeArea Notificaciones',
        channelDescription: 'Notificaciones de reportes y mensajes',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: _soundEnabled,
        enableVibration: _vibrationEnabled,
      );

      // Preparar detalles de iOS
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: _soundEnabled,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Mostrar notificación local (banner superior)
      await _localNotifications.show(
        message.hashCode,
        notification.title ?? 'Nueva notificación',
        notification.body ?? '',
        details,
        payload: payload,
      );
    }

    // Mostrar diálogo de alerta (para todas las plataformas si hay contexto disponible)
    if (navigatorKey?.currentContext != null) {
      _showNotificationDialog(
        navigatorKey!.currentContext!,
        notification.title ?? 'Nueva notificación',
        notification.body ?? '',
        imageUrl,
        type,
        id,
      );
    }
  }

  /// Mostrar notificación en web usando la API del navegador
  /// En web, las notificaciones se muestran principalmente a través del diálogo
  /// La notificación del sistema del navegador requiere configuración adicional
  Future<void> _showWebNotification({
    required String title,
    required String body,
    String? imageUrl,
    required String payload,
  }) async {
    if (kIsWeb) {
      // En web, Firebase Messaging maneja las notificaciones automáticamente
      // cuando la app está en segundo plano o cerrada
      // En primer plano, mostramos el diálogo (ya implementado arriba)
      debugPrint('Notificación web: $title - $body');
      
      // Nota: Para notificaciones del sistema del navegador en web,
      // necesitarías configurar un Service Worker y usar la API de notificaciones
      // del navegador. Por ahora, el diálogo funciona para mostrar las notificaciones
    }
  }

  void _showNotificationDialog(
    BuildContext context,
    String title,
    String body,
    String? imageUrl,
    String type,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                    const SizedBox(height: 0),
              ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToScreen(type, id);
            },
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? 'general';
    final id = data['id'] ?? '';
    _navigateToScreen(type, id);
  }

  void _navigateToScreen(String type, String id) {
    if (navigatorKey?.currentContext == null) return;

    final context = navigatorKey!.currentContext!;
    
    switch (type) {
      case 'report':
        // Navegar a detalle del reporte si tenemos el ID
        if (id.isNotEmpty) {
          // Obtener el reporte desde Firestore
          FirebaseFirestore.instance
              .collection('reports')
              .doc(id)
              .get()
              .then((doc) {
            if (doc.exists && navigatorKey?.currentContext != null) {
              final report = Report.fromMap(doc.data()!);
              Navigator.push(
                navigatorKey!.currentContext!,
                MaterialPageRoute(
                  builder: (context) => ReportDetailScreen(report: report),
                ),
              );
            }
          }).catchError((error) {
            debugPrint('Error al obtener reporte: $error');
          });
        }
        break;
      case 'chat':
        // Navegar a chat (no necesita ID)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatScreen(),
          ),
        );
        break;
      default:
        debugPrint('Tipo de notificación desconocido: $type');
    }
  }

  Future<void> unsubscribe(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': FieldValue.delete(),
    });
  }

  /// Envía notificaciones automáticamente a todos los usuarios (excepto al creador)
  /// cuando se crea un nuevo reporte
  static Future<void> sendNewReportNotification({
    required String reportId,
    required String reportTitle,
    required String reportType,
    required String creatorUserId,
    String? imageUrl,
  }) async {
    // Las notificaciones locales se manejan mediante listeners de Firestore
    // No necesitamos hacer nada aquí, los listeners mostrarán las notificaciones
    debugPrint('Notificación de nuevo reporte será mostrada localmente por el listener');
  }

  /// Envía notificaciones cuando cambia el estado de un reporte
  static Future<void> sendReportStatusChangeNotification({
    required String reportId,
    required String reportTitle,
    required String newStatus,
    required String ownerUserId,
    String? imageUrl,
  }) async {
    // Las notificaciones locales se manejan mediante listeners de Firestore
    // No necesitamos hacer nada aquí, los listeners mostrarán las notificaciones
    debugPrint('Notificación de cambio de estado será mostrada localmente por el listener');
  }

  /// Método auxiliar para enviar notificaciones usando Firestore
  /// (Cloud Functions procesará esto)
  static Future<void> _sendViaFirestore({
    required List<String> tokens,
    required String title,
    required String body,
    required String reportId,
    String? imageUrl,
    String type = 'report',
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    // Crear un documento en la colección 'notification_queue' para que Cloud Functions lo procese
    // Si no tienes Cloud Functions, puedes comentar esto y usar la API REST directamente
    for (final token in tokens) {
      await firestore.collection('notification_queue').add({
        'token': token,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': type,
          'id': reportId,
          if (imageUrl != null) 'image': imageUrl,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static String _getReportTypeLabel(String type) {
    switch (type) {
      case 'robo':
        return 'Robo';
      case 'incendio':
        return 'Incendio';
      case 'emergencia':
        return 'Emergencia';
      case 'accidente':
        return 'Accidente';
      case 'otro':
        return 'Otro';
      default:
        return type;
    }
  }

  /// Envía notificaciones automáticamente cuando se envía un mensaje en el chat
  static Future<void> sendChatMessageNotification({
    required String userName,
    required String messageText,
    required String senderUserId,
    String? imageUrl, // RF-11: URL de imagen
  }) async {
    // Las notificaciones locales se manejan mediante listeners de Firestore
    // No necesitamos hacer nada aquí, los listeners mostrarán las notificaciones
    debugPrint('Notificación de chat será mostrada localmente por el listener${imageUrl != null ? ' (con imagen)' : ''}');
  }

  static String _getStatusLabel(String status) {
    switch (status) {
      case 'activo':
        return 'Activo';
      case 'en_proceso':
        return 'En proceso';
      case 'resuelto':
        return 'Resuelto';
      default:
        return status;
    }
  }
}

