import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'notification_service.dart';
import '../models/chat_group_model.dart';
import 'location_service.dart';

/// Distritos de la provincia de Tacna
class PredefinedZones {
  static const List<Map<String, dynamic>> districts = [
    {
      'id': 'distrito_tacna',
      'name': 'Tacna',
      'description': 'Centro de la ciudad de Tacna',
      'lat': -18.0147,
      'lng': -70.2488,
      'radius': 2.0, // km
    },
    {
      'id': 'distrito_alto_alianza',
      'name': 'Alto de la Alianza',
      'description': 'Distrito al norte de Tacna',
      'lat': -17.9990,
      'lng': -70.2350,
      'radius': 1.5,
    },
    {
      'id': 'distrito_calana',
      'name': 'Calana',
      'description': 'Distrito al noroeste de Tacna',
      'lat': -17.9460,
      'lng': -70.2800,
      'radius': 1.5,
    },
    {
      'id': 'distrito_ciudad_nueva',
      'name': 'Ciudad Nueva',
      'description': 'Distrito al este de Tacna',
      'lat': -17.9950,
      'lng': -70.2100,
      'radius': 1.5,
    },
    {
      'id': 'distrito_coronel_albarracin',
      'name': 'Coronel Gregorio Albarracín',
      'description': 'Distrito al sur de Tacna',
      'lat': -18.0470,
      'lng': -70.2600,
      'radius': 1.5,
    },
    {
      'id': 'distrito_inclan',
      'name': 'Inclán',
      'description': 'Distrito al norte de Tacna',
      'lat': -17.8500,
      'lng': -70.3000,
      'radius': 2.0,
    },
    {
      'id': 'distrito_pachia',
      'name': 'Pachía',
      'description': 'Distrito al noreste de Tacna',
      'lat': -17.9100,
      'lng': -70.1300,
      'radius': 2.0,
    },
    {
      'id': 'distrito_palca',
      'name': 'Palca',
      'description': 'Distrito al noreste de Tacna',
      'lat': -17.7800,
      'lng': -70.0500,
      'radius': 2.5,
    },
    {
      'id': 'distrito_pocollay',
      'name': 'Pocollay',
      'description': 'Distrito al noroeste de Tacna',
      'lat': -17.9800,
      'lng': -70.2900,
      'radius': 1.5,
    },
    {
      'id': 'distrito_sama',
      'name': 'Sama',
      'description': 'Distrito costero al sur de Tacna',
      'lat': -18.1200,
      'lng': -70.4700,
      'radius': 3.0,
    },
    {
      'id': 'distrito_yarada',
      'name': 'La Yarada',
      'description': 'Distrito al sur de Tacna',
      'lat': -18.2000,
      'lng': -70.4000,
      'radius': 3.0,
    },
  ];

  static List<String> getDistrictIds() {
    return districts.map((d) => d['id'] as String).toList();
  }

  static Map<String, dynamic>? getDistrictById(String id) {
    try {
      return districts.firstWhere((d) => d['id'] == id);
    } catch (_) {
      return null;
    }
  }

  /// Detectar distrito por coordenadas geográficas
  static Map<String, dynamic>? getDistrictByLocation(double lat, double lng) {
    for (final district in districts) {
      final centerLat = district['lat'] as double;
      final centerLng = district['lng'] as double;
      final radius = district['radius'] as double;
      
      final distance = _calculateDistance(lat, lng, centerLat, centerLng);
      if (distance <= radius) {
        return district;
      }
    }
    return null;
  }

  /// Calcular distancia entre dos coordenadas en kilómetros
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radio de la Tierra en km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
              _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
              _sin(dLon / 2) * _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => double.parse((x).toString());
  static double _cos(double x) => double.parse((x).toString());
  static double _sqrt(double x) => double.parse((x).toString());
  static double _atan2(double y, double x) => double.parse((y / x).toString());
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

  /// Inicializar grupos predefinidos (distritos de Tacna)
  Future<void> initializePredefinedZones() async {
    try {
      for (final district in PredefinedZones.districts) {
        final districtId = district['id'] as String;
        final districtDoc = _firestore.collection('chatGroups').doc(districtId);
        final docExists = await districtDoc.get();
        
        if (!docExists.exists) {
          final group = ChatGroup(
            id: districtId,
            name: district['name'] as String,
            description: district['description'] as String,
            createdBy: 'system',
            createdByName: 'Sistema',
            createdAt: DateTime.now(),
            members: [],
            isPublic: true,
          );
          await districtDoc.set(group.toMap());
          debugPrint('✅ Distrito creado: ${district['name']}');
        }
      }
      debugPrint('✅ Todos los distritos de Tacna inicializados');
    } catch (e) {
      debugPrint('❌ Error inicializando distritos: $e');
    }
  }

  /// Obtener stream de grupos predefinidos (distritos)
  Stream<QuerySnapshot> predefinedZonesStream() {
    final districtIds = PredefinedZones.getDistrictIds();
    if (districtIds.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('chatGroups')
        .where(FieldPath.documentId, whereIn: districtIds)
        .snapshots();
  }

  /// Obtener stream de grupos públicos
  Stream<QuerySnapshot> groupsStream() {
    return _firestore
        .collection('chatGroups')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Obtener grupos del usuario actual
  Stream<QuerySnapshot> myGroupsStream(String userId) {
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
        members: [createdBy],
        isPublic: isPublic,
        imageUrl: imageUrl,
      );
      await groupDoc.set(group.toMap());
      debugPrint('✅ Grupo creado: ${group.name}');
      return null;
    } catch (e) {
      debugPrint('❌ Error al crear grupo: $e');
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
      debugPrint('✅ Usuario $userId se unió al grupo $groupId');
      return null;
    } catch (e) {
      debugPrint('❌ Error al unirse al grupo: $e');
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

      await _firestore
          .collection('chatGroups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayRemove([userId]),
      });
      debugPrint('✅ Usuario $userId salió del grupo $groupId');
      return null;
    } catch (e) {
      debugPrint('❌ Error al salir del grupo: $e');
      return 'Error al salir del grupo: $e';
    }
  }

  /// Enviar mensaje a un grupo específico
  Future<String?> sendMessage({
    required String userId,
    required String userName,
    String? text,
    String? groupId,
    String? imageUrl,
  }) async {
    try {
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
        'imageUrl': imageUrl,
        'createdAt': DateTime.now().toIso8601String(),
        'groupId': targetGroupId,
      });

      // Enviar notificación automática
      NotificationService.sendChatMessageNotification(
        userName: userName,
        messageText: text?.trim() ?? 'Imagen compartida',
        senderUserId: userId,
        imageUrl: imageUrl,
      );

      debugPrint('✅ Mensaje enviado por $userName');
      return null;
    } catch (e) {
      debugPrint('❌ Error al enviar mensaje: $e');
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
      debugPrint('✅ Mensaje reportado: $messageId');
      return null;
    } catch (e) {
      debugPrint('❌ Error al reportar mensaje: $e');
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
      debugPrint('❌ Error obteniendo grupo: $e');
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
  Future<String?> openOrCreatePrivateChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    try {
      final sortedIds = [currentUserId, otherUserId]..sort();
      final privateId = 'private_${sortedIds[0]}_${sortedIds[1]}';

      final docRef = _firestore.collection('chatGroups').doc(privateId);
      final snap = await docRef.get();

      if (!snap.exists) {
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
        await docRef.set(groupData);
        debugPrint('✅ Chat privado creado: $privateId');
      }

      setCurrentGroup(privateId);
      return privateId;
    } catch (e) {
      debugPrint('❌ Error al abrir/crear chat privado: $e');
      return null;
    }
  }

  /// Cargar mensajes antiguos (paginación)
  Future<List<QueryDocumentSnapshot>> loadOlderMessages({
    required String groupId,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      var query = _firestore
          .collection('chatGroups')
          .doc(groupId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final snapshot = await query.get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('❌ Error cargando mensajes antiguos: $e');
      return [];
    }
  }

  // ==================== PASO 2: MÉTODOS PARA DETECTAR ZONA POR UBICACIÓN ====================

  /// Detectar distrito por ubicación del usuario
  Future<Map<String, dynamic>?> detectDistrictByLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position == null) return null;
    
    final district = PredefinedZones.getDistrictByLocation(
      position.latitude,
      position.longitude,
    );
    
    if (district != null) {
      debugPrint('📍 Distrito detectado: ${district['name']}');
    } else {
      debugPrint('📍 No se detectó ningún distrito para la ubicación actual');
    }
    
    return district;
  }

  /// Unirse automáticamente al distrito detectado por ubicación
  Future<String?> autoJoinDistrict(String userId) async {
    final district = await detectDistrictByLocation();
    if (district == null) return null;
    
    final districtId = district['id'] as String;
    
    // Verificar si ya es miembro
    final isAlreadyMember = await isMember(districtId, userId);
    if (isAlreadyMember) {
      debugPrint('ℹ️ Usuario ya es miembro de ${district['name']}');
      return null;
    }
    
    final error = await joinGroup(
      groupId: districtId,
      userId: userId,
    );
    
    if (error == null) {
      debugPrint('✅ Usuario se unió automáticamente a: ${district['name']}');
    } else {
      debugPrint('❌ Error al unirse automáticamente: $error');
    }
    
    return error;
  }

  /// Obtener el distrito actual del usuario (si está dentro de alguno)
  Future<Map<String, dynamic>?> getCurrentUserDistrict(String userId) async {
    // Obtener todos los grupos del usuario
    final groupsSnapshot = await _firestore
        .collection('chatGroups')
        .where('members', arrayContains: userId)
        .get();
    
    if (groupsSnapshot.docs.isEmpty) return null;
    
    // Buscar si alguno de los grupos del usuario es un distrito predefinido
    for (final doc in groupsSnapshot.docs) {
      final district = PredefinedZones.getDistrictById(doc.id);
      if (district != null) {
        return district;
      }
    }
    
    return null;
  }

  /// Obtener lista de distritos a los que pertenece el usuario
  Future<List<Map<String, dynamic>>> getUserDistricts(String userId) async {
    final groupsSnapshot = await _firestore
        .collection('chatGroups')
        .where('members', arrayContains: userId)
        .get();
    
    final List<Map<String, dynamic>> userDistricts = [];
    
    for (final doc in groupsSnapshot.docs) {
      final district = PredefinedZones.getDistrictById(doc.id);
      if (district != null) {
        userDistricts.add(district);
      }
    }
    
    return userDistricts;
  }
}