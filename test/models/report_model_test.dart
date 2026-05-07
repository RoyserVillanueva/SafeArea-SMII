import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_safearea/models/report_model.dart';

void main() {
  group('Report Model Tests', () {
    test('fromMap should create Report from map', () {
      final map = {
        'id': 'test-id',
        'userId': 'user-id',
        'type': 'robo',
        'title': 'Test Report',
        'description': 'Test Description',
        'location': 'Test Location',
        'status': 'activo',
        'images': ['image1.jpg', 'image2.jpg'],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
        'verifiedBy': [],
        'isActive': true,
        'latitude': -18.0056,
        'longitude': -70.2483,
      };

      final report = Report.fromMap(map);

      expect(report.id, 'test-id');
      expect(report.userId, 'user-id');
      expect(report.type, 'robo');
      expect(report.title, 'Test Report');
      expect(report.description, 'Test Description');
      expect(report.location, 'Test Location');
      expect(report.status, 'activo');
      expect(report.images, hasLength(2));
      expect(report.images.first, 'image1.jpg');
      expect(report.isActive, true);
      expect(report.latitude, -18.0056);
      expect(report.longitude, -70.2483);
    });

    test('toMap should create map from Report', () {
      final report = Report(
        id: 'test-id',
        userId: 'user-id',
        type: 'incendio',
        title: 'Fire Report',
        description: 'Fire Description',
        location: 'Fire Location',
        status: 'en_proceso',
        images: ['fire1.jpg'],
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        verifiedBy: [],
        isActive: true,
      );

      final map = report.toMap();

      expect(map['id'], 'test-id');
      expect(map['userId'], 'user-id');
      expect(map['type'], 'incendio');
      expect(map['title'], 'Fire Report');
      expect(map['status'], 'en_proceso');
      expect(map['images'], hasLength(1));
      expect(map['isActive'], true);
    });

    test('copyWith should create copy with updated fields', () {
      final original = Report(
        id: 'test-id',
        userId: 'user-id',
        type: 'robo',
        title: 'Original Title',
        description: 'Original Description',
        location: 'Original Location',
        status: 'activo',
        images: [],
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        verifiedBy: [],
        isActive: true,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        status: 'resuelto',
        images: ['new-image.jpg'],
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Updated Title');
      expect(updated.status, 'resuelto');
      expect(updated.images, hasLength(1));
      expect(updated.description, original.description);
    });
  });
}

