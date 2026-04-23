import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OsmMapPickerScreen extends StatefulWidget {
  const OsmMapPickerScreen({super.key});

  @override
  State<OsmMapPickerScreen> createState() => _OsmMapPickerScreenState();
}

class _OsmMapPickerScreenState extends State<OsmMapPickerScreen> {
  static final LatLng tacnaCenter = LatLng(-18.0066, -70.2463);
  LatLng selected = tacnaCenter;
  final MapController _mapController = MapController();
  bool _isPrefetching = false;
  double _prefetchProgress = 0;

  // Bounding box aproximado de Tacna ciudad
  static const double _minLat = -18.10;
  static const double _maxLat = -17.95;
  static const double _minLng = -70.33;
  static const double _maxLng = -70.15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación (OSM)'),
        actions: [
          if (!_isPrefetching)
            IconButton(
              tooltip: 'Descargar Tacna offline',
              icon: const Icon(Icons.download),
              onPressed: _prefetchTacnaTiles,
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Usar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: tacnaCenter,
          initialZoom: 14,
          onTap: (tapPos, latLng) => setState(() => selected = latLng),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.safearea.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: selected,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lat: ${selected.latitude.toStringAsFixed(6)}, Lng: ${selected.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
              ),
              if (_isPrefetching) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _prefetchProgress),
                const SizedBox(height: 4),
                const Text('Precargando mapa de Tacna...'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _prefetchTacnaTiles() async {
    if (_isPrefetching) return;
    setState(() {
      _isPrefetching = true;
      _prefetchProgress = 0;
    });

    // Recorre una grilla sobre el bounding box para forzar la descarga de tiles
    const int stepsLat = 8; // aumenta para más detalle (más lento y más espacio)
    const int stepsLng = 8;
    const double zoom = 15; // nivel de detalle urbano

    int current = 0;
    final int total = stepsLat * stepsLng;

    for (int i = 0; i < stepsLat; i++) {
      final lat = _minLat + (i * ((_maxLat - _minLat) / (stepsLat - 1)));
      for (int j = 0; j < stepsLng; j++) {
        final lng = _minLng + (j * ((_maxLng - _minLng) / (stepsLng - 1)));
        _mapController.move(LatLng(lat, lng), zoom);
        await Future.delayed(const Duration(milliseconds: 250));
        current++;
        if (!mounted) return;
        setState(() {
          _prefetchProgress = current / total;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isPrefetching = false;
      _prefetchProgress = 1;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Área de Tacna precargada para uso offline')),
    );
  }
}


