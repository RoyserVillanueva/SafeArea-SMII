import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_safearea/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('fromMap should create UserModel from map', () {
      final map = {
        'id': 'user-id',
        'email': 'test@example.com',
        'name': 'Test User',
        'phone': '+51987654321',
        'profileImage': 'https://example.com/image.jpg',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'role': 'user',
      };

      final user = UserModel.fromMap(map);

      expect(user.id, 'user-id');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.phone, '+51987654321');
      expect(user.profileImage, 'https://example.com/image.jpg');
      expect(user.role, 'user');
      expect(user.isAdmin, false);
    });

    test('fromMap should default role to user if not provided', () {
      final map = {
        'id': 'user-id',
        'email': 'test@example.com',
        'name': 'Test User',
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      final user = UserModel.fromMap(map);

      expect(user.role, 'user');
      expect(user.isAdmin, false);
    });

    test('toMap should create map from UserModel', () {
      final user = UserModel(
        id: 'user-id',
        email: 'test@example.com',
        name: 'Test User',
        phone: '+51987654321',
        profileImage: 'https://example.com/image.jpg',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        role: 'admin',
      );

      final map = user.toMap();

      expect(map['id'], 'user-id');
      expect(map['email'], 'test@example.com');
      expect(map['name'], 'Test User');
      expect(map['phone'], '+51987654321');
      expect(map['role'], 'admin');
    });

    test('isAdmin should return true for admin role', () {
      final admin = UserModel(
        id: 'admin-id',
        email: 'admin@example.com',
        name: 'Admin User',
        createdAt: DateTime.now(),
        role: 'admin',
      );

      expect(admin.isAdmin, true);
      expect(admin.canModerate(), true);
    });

    test('isAdmin should return false for user role', () {
      final user = UserModel(
        id: 'user-id',
        email: 'user@example.com',
        name: 'Regular User',
        createdAt: DateTime.now(),
        role: 'user',
      );

      expect(user.isAdmin, false);
      expect(user.canModerate(), false);
    });
  });
}

