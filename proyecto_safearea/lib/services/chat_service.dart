import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../models/chat_group_model.dart';

/// Zonas predefinidas de Tacna
class PredefinedZones {
  static const List<Map<String, dynamic>> zones = [
    {
      'id': 'zona_centro',
      'name': 'Zona Centro',
      'description': 'Chat para residentes y usuarios del Centro de Tacna',
    },
    {
      'id': 'zona_sur',
      'name': 'Zona Sur',
      'description': 'Chat para residentes y usuarios de la Zona Sur de Tacna',
    },
    {
      'id': 'zona_norte',
      'name': 'Zona Norte',
      'description': 'Chat para residentes y usuarios de la Zona Norte de Tacna',
    },
  ];

  static String getZoneId(String zoneName) {
    return zones.firstWhere(
      (zone) => zone['name'] == zoneName,
      orElse: () => zones[0],
    )['id'] as String;
  }
}

class ChatService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentGroupId;

  /// Obtener stream de mensajes de un grupo específico
  Stream<QuerySnapshot> messagesStream({String? groupId}) {
    final targetGroupId = groupId ?? _currentGroupId ?? 'global';
    return _firestore
        .collection('chatGroups')
        .doc(targetGroupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Establecer el grupo actual
  void setCurrentGroup(String? groupId) {
    _currentGroupId = groupId;
    notifyListeners();
  }

  /// Inicializar grupos predefinidos (zones)
  Future<void> initializePredefinedZones() async {
    try {
      for (final zone in PredefinedZones.zones) {
        final zoneId = zone['id'] as String;
        final zoneDoc = _firestore.collection('chatGroups').doc(zoneId);
        final docExists = await zoneDoc.get();
        
        if (!docExists.exists) {
          // Crear el grupo predefinido
          final group = ChatGroup(
            id: zoneId,
            name: zone['name'] as String,
            description: zone['description'] as String,
            createdBy: 'system',
            createdByName: 'Sistema',
            createdAt: DateTime.now(),
            members: [],
            isPublic: true,
          );
          await zoneDoc.set(group.toMap());
        }
      }
    } catch (e) {
      debugPrint('Error inicializando zonas predefinidas: $e');
    }
  }

  /// Obtener stream de grupos predefinidos (zonas)
  Stream<QuerySnapshot> predefinedZonesStream() {
    final zoneIds = PredefinedZones.zones.map((z) => z['id'] as String).toList();
    if (zoneIds.isEmpty) {
      return const Stream.empty();
    }
    // Firestore whereIn soporta hasta 10 elementos
    return _firestore
        .collection('chatGroups')
        .where(FieldPath.documentId, whereIn: zoneIds)
        .snapshots();
  }

  /// Obtener stream de grupos creados por usuarios (no predefinidos)
  Stream<QuerySnapshot> userGroupsStream() {
    return _firestore
        .collection('chatGroups')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Obtener stream de todos los grupos públicos (para compatibilidad)
  Stream<QuerySnapshot> groupsStream() {
    return _firestore
        .collection('chatGroups')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Obtener grupos del usuario actual
  Stream<QuerySnapshot> myGroupsStream(String userId) {
    // No usar orderBy para evitar índice compuesto - ordenamos en memoria
    return _firestore
        .collection('chatGroups')
        .where('members', arrayContains: userId)
        .snapshots();
  }

  /// Crear un nuevo grupo de chat
  Future<String?> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required String createdByName,
    bool isPublic = true,
    String? imageUrl,
  }) async {
    try {
      final groupDoc = _firestore.collection('chatGroups').doc();
      final group = ChatGroup(
        id: groupDoc.id,
        name: name,
        description: description,
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: DateTime.now(),
        members: [createdBy], // El creador se agrega automáticamente
        isPublic: isPublic,
        imageUrl: imageUrl,
      );
      await groupDoc.set(group.toMap());
      return null;
    } catch (e) {
      return 'Error al crear grupo: $e';
    }
  }

  /// Unirse a un grupo
  Future<String?> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayUnion([userId]),
      });
      return null;
    } catch (e) {
      return 'Error al unirse al grupo: $e';
    }
  }

  /// Salir de un grupo
  Future<String?> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      final groupDoc = await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .get();
      
      if (!groupDoc.exists) {
        return 'El grupo no existe';
      }

      final data = groupDoc.data()!;
      final members = List<String>.from(data['members'] ?? []);

      // Siempre quitar al usuario de la lista de miembros; NUNCA eliminar el grupo
      // (requisito: las zonas/grupos no deben eliminarse al salir)
      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayRemove([userId]),
      });
      return null;
    } catch (e) {
      return 'Error al salir del grupo: $e';
    }
  }

  /// Enviar mensaje a un grupo específico
  Future<String?> sendMessage({
    required String userId,
    required String userName,
    String? text,
    String? groupId,
    String? imageUrl, // RF-11: URL de imagen
  }) async {
    try {
      // Validar que haya al menos texto o imagen
      if ((text == null || text.trim().isEmpty) && imageUrl == null) {
        return 'El mensaje debe tener texto o imagen';
      }
      
      final targetGroupId = groupId ?? _currentGroupId ?? 'global';
      final doc = _firestore
          .collection('chatGroups')
          .doc(targetGroupId)
          .collection('messages')
          .doc();
      await doc.set({
        'id': doc.id,
        'userId': userId,
        'userName': userName,
        'text': text?.trim() ?? '',
        'imageUrl': imageUrl, // RF-11: URL de imagen
        'createdAt': DateTime.now().toIso8601String(),
        'groupId': targetGroupId,
      });

      // Enviar notificación automática a todos los usuarios del grupo (excepto el remitente)
      NotificationService.sendChatMessageNotification(
        userName: userName,
        messageText: text?.trim() ?? 'Imagen compartida',
        senderUserId: userId,
        imageUrl: imageUrl, // RF-11: Incluir imagen en notificación
      );

      return null;
    } catch (e) {
      return 'Error al enviar mensaje: $e';
    }
  }

  /// Reportar un mensaje
  Future<String?> reportMessage({
    required String messageId,
    String? groupId,
  }) async {
    try {
      final targetGroupId = groupId ?? _currentGroupId ?? 'global';
      await _firestore
          .collection('chatGroups')
          .doc(targetGroupId)
          .collection('messages')
          .doc(messageId)
          .set({'reported': true}, SetOptions(merge: true));
      return null;
    } catch (e) {
      return 'Error al reportar mensaje: $e';
    }
  }

  /// Obtener información de un grupo
  Future<ChatGroup?> getGroup(String groupId) async {
    try {
      final doc = await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .get();
      if (!doc.exists) return null;
      return ChatGroup.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  /// Verificar si el usuario es miembro del grupo
  Future<bool> isMember(String groupId, String userId) async {
    try {
      final group = await getGroup(groupId);
      if (group == null) return false;
      return group.members.contains(userId);
    } catch (e) {
      return false;
    }
  }

  /// Abrir o crear un chat privado entre dos usuarios
  /// Solo texto: se reutiliza la infraestructura de grupos, pero con type "private"
  Future<String?> openOrCreatePrivateChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    try {
      // Generar un ID estable para el chat privado entre dos usuarios
      final sortedIds = [currentUserId, otherUserId]..sort();
      final privateId = 'private_${sortedIds[0]}_${sortedIds[1]}';

      final docRef = _firestore.collection('chatGroups').doc(privateId);
      final snap = await docRef.get();

      if (!snap.exists) {
        // Crear el grupo privado
        final groupData = {
          'id': privateId,
          'name': 'Chat con $otherUserName',
          'description': 'Chat privado entre usuarios',
          'createdBy': currentUserId,
          'createdByName': currentUserName,
          'createdAt': DateTime.now().toIso8601String(),
          'members': [currentUserId, otherUserId],
          'isPublic': false,
          'type': 'private',
        };
        await docRef.set(groupData, SetOptions(merge: true));
      }

      // Establecer grupo actual en el servicio
      setCurrentGroup(privateId);
      return privateId;
    } catch (e) {
      debugPrint('Error al abrir/crear chat privado: $e');
      return null;
    }
  }
}
