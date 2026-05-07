class ChatGroup {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final List<String> members; // IDs de usuarios
  final bool isPublic; // true = público, false = privado
  final String? imageUrl;

  ChatGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.members,
    this.isPublic = true,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'members': members,
      'isPublic': isPublic,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  factory ChatGroup.fromMap(Map<String, dynamic> map) {
    return ChatGroup(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: _parseDate(map['createdAt']),
      members: List<String>.from(map['members'] ?? []),
      isPublic: map['isPublic'] ?? true,
      imageUrl: map['imageUrl'],
    );
  }

  ChatGroup copyWith({
    String? name,
    String? description,
    List<String>? members,
    bool? isPublic,
    String? imageUrl,
  }) {
    return ChatGroup(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
      members: members ?? this.members,
      isPublic: isPublic ?? this.isPublic,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String) return DateTime.parse(v);
  try {
    final toDate = v.toDate as DateTime Function();
    return toDate();
  } catch (_) {
    return DateTime.now();
  }
}

