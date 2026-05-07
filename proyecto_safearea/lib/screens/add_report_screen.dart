import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/loading_button.dart';
import 'osm_map_picker_screen.dart';
import 'reports_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(); // 6.3 Implementación de geolocalizacion automatica
  String? _lastPickedLatLng; // "lat,lng" para referencia interna
  double? _lat;
  double? _lng;
  // 6.3 Implementación de geolocalizacion automatica
  // Para búsqueda automática de ubicación
  List<dynamic> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  String _selectedType = 'robo';
  final List<String> _reportTypes = ['robo', 'incendio', 'emergencia', 'accidente', 'otro'];
  
  // RF-11: Imágenes
  final StorageService _storageService = StorageService();
  final List<XFile> _selectedImages = [];
  bool _isUploadingImages = false;

  Future<void> _selectImages() async {
    // Mostrar diálogo para elegir fuente
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // Seleccionar imagen
    // 6.4. Implementar cámara y galería
    // Captura y selección múltiple funcionando con compresión automática
    final images = await _storageService.pickImage(source: source);
    if (images != null && mounted) {
      setState(() {
        _selectedImages.add(images);
        // Limitar a 5 imágenes
        if (_selectedImages.length > 5) {
          _selectedImages.removeRange(5, _selectedImages.length);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Máximo 5 imágenes permitidas')),
          );
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createReport() async {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final reportService = Provider.of<ReportService>(context, listen: false);

      // RF-11: Subir imágenes primero
      // 6.4. Implementar cámara y galería
      // Captura y selección múltiple funcionando con compresión automática
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        setState(() {
          _isUploadingImages = true;
        });

        try {
          imageUrls = await _storageService.uploadImageFiles(
            files: _selectedImages,
            folder: 'reports',
          );

          if (!mounted) return;
          setState(() {
            _isUploadingImages = false;
          });

          if (imageUrls.isEmpty && _selectedImages.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al subir imágenes. Intentando crear reporte sin imágenes...')),
            );
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _isUploadingImages = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir imágenes: $e')),
          );
          return;
        }
      }

      final error = await reportService.createReport(
        userId: authService.currentUser!.id,
        type: _selectedType,
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        latitude: _lat,
        longitude: _lng,
        images: imageUrls, // RF-11: URLs de imágenes subidas
      );

      if (!mounted) return;
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Limpiar formulario
        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        _selectedImages.clear();
        _lat = null;
        _lng = null;
        setState(() {});
        // Navegar explícitamente a la pantalla de Reportes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ReportsScreen()),
          (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'robo':
        return 'Robo';
      case 'incendio':
        return 'Incendio';
      case 'emergencia':
        return 'Emergencia';
      case 'accidente':
        return 'Accidente';
      case 'otro':
        return 'Otro';
      default:
        return type;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final base = kIsWeb ? 'https://geocode.maps.co' : 'https://nominatim.openstreetmap.org';
      final uri = Uri.parse('$base/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
      final headers = { 'User-Agent': 'safearea-app/1.0' };
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El servicio de ubicación está desactivado. Actívalo y vuelve a intentarlo.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado.')), 
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado permanentemente. Habilítalo desde ajustes.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lat = position.latitude;
      _lng = position.longitude;
      _lastPickedLatLng = '${position.latitude},${position.longitude}';

      final pretty = await _reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _locationController.text = pretty ?? _lastPickedLatLng!;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación actual: $e')),
      );
    }
  }

  // Búsqueda automática mientras escribe - Solo en Tacna y sus 11 distritos
  Future<void> _searchLocation(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation = false;
      });
      _hideOverlay();
      return;
    }

    setState(() => _isSearchingLocation = true);

    try {
      final base = kIsWeb ? 'https://geocode.maps.co' : 'https://nominatim.openstreetmap.org';
      // Bounding box ampliado para incluir Tacna y todos sus distritos
      // Área completa del departamento de Tacna: lat[-18.35, -17.60], lng[-70.70, -69.80]
      // Lista de distritos de Tacna para validación
      const tacnaDistricts = [
        'tacna',
        'alto de la alianza',
        'calana',
        'ciudad nueva',
        'coronel gregorio albarracín',
        'gregorio albarracín',
        'inclán',
        'pachía',
        'palca',
        'pocollay',
        'sama',
        'la yarada',
        'yarada',
        'los palos'
      ];
      
      final queryWithTacna = '$query, Tacna, Perú';
      final uri = Uri.parse(
        '$base/search?format=jsonv2&q=${Uri.encodeComponent(queryWithTacna)}&addressdetails=1&limit=15&countrycodes=pe&bounded=1&viewbox=-70.70,-18.35,-69.80,-17.60'
      );
      final res = await http.get(uri, headers: {'User-Agent': 'safearea-app/1.0'});
      
      if (res.statusCode == 200) {
        final results = json.decode(res.body) as List<dynamic>;
        // Filtrar resultados que estén dentro del área geográfica de Tacna
        // Verificar coordenadas y nombres de distritos
        final filteredResults = results.where((result) {
          final name = (result['display_name'] as String? ?? '').toLowerCase();
          final lat = double.tryParse(result['lat']?.toString() ?? '');
          final lon = double.tryParse(result['lon']?.toString() ?? '');
          
          // Verificar coordenadas dentro del bounding box ampliado
          final inBounds = lat != null && lon != null &&
              lat >= -18.35 && lat <= -17.60 &&
              lon >= -70.70 && lon <= -69.80;
          
          // Verificar si el nombre contiene algún distrito de Tacna
          final containsDistrict = tacnaDistricts.any((district) => name.contains(district));
          
          return inBounds || containsDistrict;
        }).take(5).toList();
        
        setState(() {
          _locationSuggestions = filteredResults;
          _isSearchingLocation = false;
        });
        _showOverlay();
      } else {
        setState(() {
          _locationSuggestions = [];
          _isSearchingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation = false;
      });
    }
  }

  void _selectLocationSuggestion(Map<String, dynamic> result) {
    final name = result['display_name'] as String? ?? '';
    _locationController.text = name;
    final latStr = result['lat'] as String?;
    final lonStr = result['lon'] as String?;
    if (latStr != null && lonStr != null) {
      _lat = double.tryParse(latStr);
      _lng = double.tryParse(lonStr);
      _lastPickedLatLng = '$latStr,$lonStr';
    }
    setState(() => _locationSuggestions = []);
    _hideOverlay();
    FocusScope.of(context).unfocus();
  }

  void _showOverlay() {
    _hideOverlay();
    if (_locationSuggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _locationSuggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _locationSuggestions[i] as Map<String, dynamic>;
                  final name = r['display_name'] as String? ?? '';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, size: 20),
                    title: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _selectLocationSuggestion(r),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final reportService = Provider.of<ReportService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Reporte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Tipo de Reporte (RF-06)
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _reportTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Tipo de Incidente',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Título
              AuthTextField(
                label: 'Título del Reporte',
                icon: Icons.title,
                controller: _titleController,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa un título';
                  if (value.length < 4) return 'El título debe tener mínimo 4 caracteres';
                  if (value.length > 80) return 'Máximo 80 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa una descripción';
                  if (value.length < 10) return 'La descripción debe tener mínimo 10 caracteres';
                  if (value.length > 500) return 'Máximo 500 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Ubicación - Solución mejorada integrada
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ubicación',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'Escribe o busca una dirección...',
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: _isSearchingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.my_location, size: 20),
                                    tooltip: 'Usar mi ubicación',
                                    onPressed: _useCurrentLocation,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.search, size: 20),
                                    tooltip: 'Buscar',
                                    onPressed: () {
                                      final query = _locationController.text.trim();
                                      if (query.isNotEmpty) {
                                        _searchLocation(query);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.map, size: 20),
                                    tooltip: 'Elegir en mapa',
                                    onPressed: () async {
                                      _hideOverlay();
                                      final picked = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const OsmMapPickerScreen(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      if (picked != null) {
                                        _lat = picked.latitude;
                                        _lng = picked.longitude;
                                        _lastPickedLatLng =
                                            '${picked.latitude},${picked.longitude}';
                                        final pretty = await _reverseGeocode(
                                          picked.latitude,
                                          picked.longitude,
                                        );
                                        _locationController.text =
                                            pretty ?? _lastPickedLatLng!;
                                      }
                                    },
                                  ),
                                ],
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.trim().length >= 3) {
                          _searchLocation(value);
                        } else {
                          setState(() => _locationSuggestions = []);
                          _hideOverlay();
                        }
                      },
                      onTap: () {
                        if (_locationSuggestions.isNotEmpty) {
                          _showOverlay();
                        }
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa la ubicación';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // RF-11: Sección de imágenes
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Imágenes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedImages.length}/5',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes agregar hasta 5 imágenes para documentar el incidente',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              
              // Botón para agregar imágenes
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Agregar imagen'),
                onPressed: _isUploadingImages ? null : _selectImages,
              ),
              const SizedBox(height: 12),
              
              // Grid de imágenes seleccionadas
              if (_selectedImages.isNotEmpty) ...[
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      final image = _selectedImages[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(image.path, fit: BoxFit.cover, height: 120, width: 120)
                                  : Image.file(
                                      File(image.path),
                                      fit: BoxFit.cover,
                                      height: 120,
                                      width: 120,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(32, 32),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _removeImage(index),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 24),

              LoadingButton(
                text: _isUploadingImages ? 'Subiendo imágenes...' : 'Crear Reporte',
                onPressed: _isUploadingImages ? null : () => _createReport(),
                isLoading: reportService.isLoading || _isUploadingImages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}