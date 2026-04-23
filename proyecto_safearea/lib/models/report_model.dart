import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String description;
  final String location;
  final String status;
  final List<String> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> verifiedBy;
  final bool isActive;
  final double? latitude; // opcional
  final double? longitude; // opcional

  Report({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    required this.verifiedBy,
    required this.isActive,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'description': description,
      'location': location,
      'status': status,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'verifiedBy': verifiedBy,
      'isActive': isActive,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'],
      userId: map['userId'],
      type: map['type'],
      title: map['title'],
      description: map['description'],
      location: map['location'],
      status: map['status'],
      images: List<String>.from(map['images']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      verifiedBy: List<String>.from(map['verifiedBy']),
      isActive: map['isActive'],
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : null,
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : null,
    );
  }

  Report copyWith({
    String? type,
    String? title,
    String? description,
    String? location,
    String? status,
    List<String>? images,
    DateTime? updatedAt,
    List<String>? verifiedBy,
    bool? isActive,
    double? latitude,
    double? longitude,
  }) {
    return Report(
      id: id,
      userId: userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      status: status ?? this.status,
      images: images ?? this.images,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  
  // Si es String, parsearlo
  if (v is String) {
    try {
      return DateTime.parse(v);
    } catch (_) {
      return DateTime.now();
    }
  }
  
  // Si es Timestamp de Firestore
  try {
    if (v is Timestamp) {
      return v.toDate();
    }
    // Intentar llamar toDate() si existe
    final toDate = v.toDate;
    if (toDate is Function) {
      return toDate() as DateTime;
    }
  } catch (_) {
    // Si falla, intentar como número (milliseconds)
    if (v is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      } catch (_) {
        return DateTime.now();
      }
    }
  }
  
  return DateTime.now();
}