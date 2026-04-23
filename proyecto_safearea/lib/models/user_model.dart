import 'package:flutter/foundation.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? profileImage;
  final DateTime createdAt;
  final String role; // 'user' o 'admin'
  final bool isActive; // RF-16: Estado activo/inactivo

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.profileImage,
    required this.createdAt,
    this.role = 'user', // Por defecto es usuario normal
    this.isActive = true, // RF-16: Por defecto activo
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'role': role,
      'isActive': isActive, // RF-16
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Debug: verificar el campo role
    final roleValue = map['role'];
    debugPrint('🔍 UserModel.fromMap - role raw value: $roleValue (tipo: ${roleValue.runtimeType})');
    
    // Normalizar el rol (por si viene con espacios, mayúsculas o comillas)
    String role = 'user'; // Default
    if (roleValue != null) {
      role = roleValue.toString().trim().toLowerCase();
      // Eliminar comillas si existen (al inicio y final)
      if (role.startsWith('"') && role.endsWith('"')) {
        role = role.substring(1, role.length - 1);
      }
      if (role.startsWith("'") && role.endsWith("'")) {
        role = role.substring(1, role.length - 1);
      }
      debugPrint('🔍 UserModel.fromMap - role normalizado: "$role"');
      debugPrint('🔍 UserModel.fromMap - longitud del role: ${role.length}');
      debugPrint('🔍 UserModel.fromMap - role == "admin": ${role == "admin"}');
      debugPrint('🔍 UserModel.fromMap - role bytes: ${role.codeUnits}');
    }
    
    final user = UserModel(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      phone: map['phone'],
      profileImage: map['profileImage'],
      createdAt: DateTime.parse(map['createdAt']),
      role: role, // Usar el valor normalizado
      isActive: map['isActive'] ?? true, // RF-16: Compatibilidad, por defecto activo
    );
    
    debugPrint('🔍 UserModel creado - role final: "${user.role}", isAdmin: ${user.isAdmin}');
    debugPrint('🔍 UserModel creado - role == "admin" directo: ${user.role == "admin"}');
    
    return user;
  }

  /// Verificar si el usuario es administrador
  bool get isAdmin {
    final result = role == 'admin';
    debugPrint('🔐 isAdmin getter - role: "$role", role == "admin": ${role == "admin"}, resultado: $result');
    debugPrint('🔐 isAdmin getter - role.length: ${role.length}, "admin".length: ${"admin".length}');
    if (role.length == "admin".length && role != "admin") {
      debugPrint('🔐 isAdmin getter - ⚠️ CUIDADO: Longitudes iguales pero valores diferentes!');
      debugPrint('🔐 isAdmin getter - role.codeUnits: ${role.codeUnits}');
      debugPrint('🔐 isAdmin getter - "admin".codeUnits: ${"admin".codeUnits}');
    }
    return result;
  }

  /// Verificar si el usuario puede moderar (es admin o tiene permisos especiales)
  bool canModerate() => isAdmin;

  /// Crear una copia del usuario con nuevos valores
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? profileImage,
    DateTime? createdAt,
    String? role,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}