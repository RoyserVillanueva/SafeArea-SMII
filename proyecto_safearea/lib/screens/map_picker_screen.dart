import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng tacnaCenter = LatLng(-18.0066, -70.2463);
  LatLng selected = tacnaCenter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, selected);
            },
            child: const Text('Usar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: tacnaCenter, zoom: 14),
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        markers: {
          Marker(
            markerId: const MarkerId('sel'),
            position: selected,
            draggable: true,
            onDragEnd: (p) => setState(() => selected = p),
          )
        },
        onTap: (p) => setState(() => selected = p),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Lat: ${selected.latitude.toStringAsFixed(6)}, Lng: ${selected.longitude.toStringAsFixed(6)}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}


