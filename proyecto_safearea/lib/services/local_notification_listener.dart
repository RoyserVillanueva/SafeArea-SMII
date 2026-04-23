import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../models/report_model.dart';
import '../screens/report_detail_screen.dart';
import 'notification_service.dart';

/// Servicio que escucha cambios en Firestore y muestra notificaciones locales
class LocalNotificationListener {
  static LocalNotificationListener? _instance;
  static LocalNotificationListener get instance => 
      _instance ??= LocalNotificationListener._();
  
  LocalNotificationListener._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  StreamSubscription? _chatSubscription;
  StreamSubscription? _reportsSubscription;
  String? _currentUserId;
  String? _lastChatMessageId;
  final Set<String> _knownReportIds = {};
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  /// Inicializar el listener de notificaciones locales
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _loadUserSettings();
    
    // En Web, solo inicializamos el listener (sin notificaciones del sistema)
    // En Android/iOS, inicializamos notificaciones del sistema
    if (!kIsWeb) {
      // Inicializar notificaciones locales (solo en Android/iOS)
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

      // Crear canal de notificación Android
      if (Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          'safearea_channel',
          'SafeArea Notificaciones',
          description: 'Notificaciones de reportes y mensajes',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }
    }
    
    // Iniciar listeners (funciona tanto en Web como Android/iOS)
    _startChatListener();
    _startReportsListener();
  }

  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      debugPrint('LocalNotificationListener - settings: notifications=$_notificationsEnabled, sound=$_soundEnabled, vibration=$_vibrationEnabled');
    } catch (e) {
      debugPrint('Error cargando configuración de notificaciones locales: $e');
    }
  }

  /// Iniciar listener para mensajes del chat
  void _startChatListener() {
    _chatSubscription?.cancel();
    
    // Usar collectionGroup para escuchar mensajes de todos los grupos de chat
    // (chatGroups/{groupId}/messages)
    _chatSubscription = _firestore
        .collectionGroup('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty || _currentUserId == null) return;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final messageId = doc.id;
        final userId = data['userId'] as String?;
        final userName = data['userName'] as String?;
        final text = data['text'] as String?;

        // Ignorar si es el mismo mensaje que ya procesamos
        if (messageId == _lastChatMessageId) return;
        
        // Ignorar si el mensaje es del usuario actual
        if (userId == _currentUserId) {
          _lastChatMessageId = messageId;
          return;
        }

        _lastChatMessageId = messageId;

        debugPrint('Nuevo mensaje detectado: $userName - $text');

        // Respetar configuración de notificaciones
        if (!_notificationsEnabled) {
          debugPrint('Notificaciones desactivadas por el usuario. Chat no notificado.');
          return;
        }

        // Mostrar notificación local (Android/iOS) o diálogo (Web)
        if (kIsWeb) {
          // En Web: mostrar solo diálogo
          _showNotificationDialog(
            'Nuevo mensaje de ${userName ?? "Usuario"}',
            text ?? '',
            'chat',
            messageId,
          );
        } else {
          // En Android/iOS: mostrar notificación del sistema
          _showLocalNotification(
            title: 'Nuevo mensaje de ${userName ?? "Usuario"}',
            body: text ?? '',
            payload: 'chat|$messageId',
          );
        }

        debugPrint('Notificación local de chat: $userName - $text');
      }
    });
  }

  /// Iniciar listener para nuevos reportes
  void _startReportsListener() {
    _reportsSubscription?.cancel();
    
    _reportsSubscription = _firestore
        .collection('reports')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty || _currentUserId == null) return;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final reportId = doc.id;
        final title = data['title'] as String?;
        final type = data['type'] as String?;
        final status = data['status'] as String?;

        // Solo notificar reportes con estado "activo"
        if (status != null && status != 'activo') {
          continue;
        }

        // Ignorar si ya conocemos este reporte
        if (_knownReportIds.contains(reportId)) continue;
        
        _knownReportIds.add(reportId);

        // Preparar etiqueta del tipo
        final typeLabel = _getReportTypeLabel(type ?? 'otro');

        debugPrint('Nuevo reporte detectado: $typeLabel - $title');

        // Respetar configuración de notificaciones
        if (!_notificationsEnabled) {
          debugPrint('Notificaciones desactivadas por el usuario. Reporte no notificado.');
          return;
        }

        // Mostrar notificación local (Android/iOS) o diálogo (Web)
        if (kIsWeb) {
          // En Web: mostrar solo diálogo
          _showNotificationDialog(
            'Nuevo reporte: $typeLabel',
            title ?? 'Nuevo reporte en la comunidad',
            'report',
            reportId,
          );
        } else {
          // En Android/iOS: mostrar notificación del sistema
          _showLocalNotification(
            title: 'Nuevo reporte: $typeLabel',
            body: title ?? 'Nuevo reporte en la comunidad',
            payload: 'report|$reportId',
          );
        }

        debugPrint('Notificación local de nuevo reporte: $title');
      }
    });
  }

  /// Mostrar notificación local
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) return;

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

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _soundEnabled,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );

    // Mostrar también diálogo si hay contexto disponible
    if (NotificationService.navigatorKey?.currentContext != null) {
      final data = payload.split('|');
      if (data.length >= 2) {
        final type = data[0];
        final id = data[1];
        _showNotificationDialog(title, body, type, id);
      }
    }
  }

  /// Mostrar diálogo de notificación
  void _showNotificationDialog(String title, String body, String type, String id) {
    final context = NotificationService.navigatorKey?.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToScreen(type, id);
            },
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }

  /// Navegar a la pantalla correspondiente
  void _navigateToScreen(String type, String id) {
    final context = NotificationService.navigatorKey?.currentContext;
    if (context == null) return;

    switch (type) {
      case 'chat':
        Navigator.pushNamed(context, '/chat');
        break;
      case 'report':
        FirebaseFirestore.instance
            .collection('reports')
            .doc(id)
            .get()
            .then((doc) {
          if (doc.exists && NotificationService.navigatorKey?.currentContext != null) {
            final report = Report.fromMap(doc.data()!);
            Navigator.push(
              NotificationService.navigatorKey!.currentContext!,
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(report: report),
              ),
            );
          }
        }).catchError((error) {
          debugPrint('Error al obtener reporte: $error');
        });
        break;
      default:
        debugPrint('Tipo de notificación desconocido: $type');
    }
  }

  /// Obtener etiqueta del tipo de reporte
  String _getReportTypeLabel(String type) {
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

  /// Limpiar recursos
  void dispose() {
    _chatSubscription?.cancel();
    _reportsSubscription?.cancel();
    _currentUserId = null;
    _lastChatMessageId = null;
    _knownReportIds.clear();
  }
}

