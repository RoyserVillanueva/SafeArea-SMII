// 9.3 Distancia
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double EARTH_RADIUS_KM = 6371.0;

  /// Obtener la ubicación actual del usuario
  static Future<Position?> getCurrentLocation() async {
    try {
      // Verificar si los servicios de ubicación están habilitados
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Servicios de ubicación deshabilitados');
        return null;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Permiso de ubicación denegado');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Permiso de ubicación denegado permanentemente');
        return null;
      }

      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      debugPrint('📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación: $e');
      return null;
    }
  }

  /// Calcular distancia entre dos coordenadas en kilómetros
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
              _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
              _sin(dLon / 2) * _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    
    return EARTH_RADIUS_KM * c;
  }

  /// Verificar si una ubicación está dentro de un radio (km)
  static bool isWithinRadius(
    double userLat, double userLon,
    double reportLat, double reportLon,
    double radiusKm,
  ) {
    final distance = calculateDistance(userLat, userLon, reportLat, reportLon);
    return distance <= radiusKm;
  }

  // Funciones matemáticas auxiliares
  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) => double.parse((x).toString());
  static double _cos(double x) => double.parse((x).toString());
  static double _sqrt(double x) => double.parse((x).toString());
  static double _atan2(double y, double x) => double.parse((y / x).toString());
}