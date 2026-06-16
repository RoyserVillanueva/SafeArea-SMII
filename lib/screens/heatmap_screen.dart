// lib/screens/heatmap_screen.dart
// 16.4. Implementar mapa de calor de incidentes

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  bool _isLoading = true;
  List<LatLng> _incidentPoints = [];
  List<Map<String, dynamic>> _incidents = [];
  String _errorMessage = '';

  // Centro de Tacna
  static const LatLng _tacnaCenter = LatLng(-18.0147, -70.2488);

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('isActive', isEqualTo: true)
          .get();

      final points = <LatLng>[];
      final incidents = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;

        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
          incidents.add({
            'id': doc.id,
            'title': data['title'] ?? 'Sin título',
            'type': data['type'] ?? 'otro',
            'status': data['status'] ?? 'activo',
            'latitude': lat,
            'longitude': lng,
          });
        }
      }

      setState(() {
        _incidentPoints = points;
        _incidents = incidents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar incidentes: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Calor de Incidentes'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncidents,
            tooltip: 'Recargar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _buildHeatmapContent(),
      floatingActionButton: _incidents.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                _showIncidentStats();
              },
              icon: const Icon(Icons.info_outline),
              label: Text('${_incidents.length} incidentes'),
              backgroundColor: colorScheme.primary,
            )
          : null,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadIncidents,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapContent() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_incidentPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay incidentes con ubicación',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los reportes deben tener coordenadas para aparecer en el mapa',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadIncidents,
              child: const Text('Recargar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Mapa
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _tacnaCenter,
              initialZoom: 13,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              // Capa de tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safearea.app',
              ),
              // Capa de calor (puntos con opacidad)
              // NOTA: FlutterMap no tiene heatmap nativo.
              // Usamos MarkerLayer con círculos de colores según densidad
              MarkerLayer(
                markers: _buildHeatmapMarkers(),
              ),
            ],
          ),
        ),
        // Leyenda
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Robo', Colors.red),
              _buildLegendItem('Incendio', Colors.orange),
              _buildLegendItem('Emergencia', Colors.purple),
              _buildLegendItem('Accidente', Colors.blue),
              _buildLegendItem('Otro', Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _buildHeatmapMarkers() {
    final markers = <Marker>[];

    for (final incident in _incidents) {
      final type = incident['type'] as String;
      final color = _getTypeColor(type);
      final title = incident['title'] as String;

      markers.add(
        Marker(
          point: LatLng(
            incident['latitude'] as double,
            incident['longitude'] as double,
          ),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () {
              _showIncidentDetail(incident);
            },
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${_getTypeIcon(type)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'robo':
        return Colors.red;
      case 'incendio':
        return Colors.orange;
      case 'emergencia':
        return Colors.purple;
      case 'accidente':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case 'robo':
        return '🔴';
      case 'incendio':
        return '🟠';
      case 'emergencia':
        return '🟣';
      case 'accidente':
        return '🔵';
      default:
        return '⚪';
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showIncidentDetail(Map<String, dynamic> incident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(incident['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo: ${incident['type']}'),
            Text('Estado: ${incident['status']}'),
            Text('Lat: ${incident['latitude'].toStringAsFixed(6)}'),
            Text('Lng: ${incident['longitude'].toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showIncidentStats() {
    final typeCounts = <String, int>{};
    for (final incident in _incidents) {
      final type = incident['type'] as String;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estadísticas de Incidentes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total de incidentes: ${_incidents.length}'),
              const Divider(),
              ...typeCounts.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  trailing: Text(entry.value.toString()),
                  dense: true,
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}