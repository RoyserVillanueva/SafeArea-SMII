import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/report_service.dart';
import '../models/report_model.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/loading_button.dart';
import 'osm_map_picker_screen.dart';

class EditReportScreen extends StatefulWidget {
  final Report report;

  const EditReportScreen({super.key, required this.report});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedType = 'robo';
  final List<String> _reportTypes = ['robo', 'incendio', 'emergencia', 'accidente', 'otro'];
  
  // Para búsqueda automática de ubicación
  List<dynamic> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.report.title;
    _descriptionController.text = widget.report.description;
    _locationController.text = widget.report.location;
    _selectedType = widget.report.type;
  }

  void _updateReport() async {
    if (_formKey.currentState!.validate()) {
      final reportService = Provider.of<ReportService>(context, listen: false);

      final updatedReport = widget.report.copyWith(
        type: _selectedType,
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        updatedAt: DateTime.now(),
      );

      final error = await reportService.updateReport(updatedReport);

      if (!mounted) return;
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte actualizado exitosamente')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} a las ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Hace unos momentos';
    }
  }

  String _getExpirationMessage(int days, int totalHours) {
    final remainingHours = totalHours % 24;
    if (days > 0 && remainingHours > 0) {
      return 'El plazo de edición expiró hace $days día${days > 1 ? 's' : ''} y $remainingHours hora${remainingHours > 1 ? 's' : ''}';
    } else if (days > 0) {
      return 'El plazo de edición expiró hace $days día${days > 1 ? 's' : ''}';
    } else if (remainingHours > 0) {
      return 'El plazo de edición expiró hace $remainingHours hora${remainingHours > 1 ? 's' : ''}';
    } else {
      return 'El plazo de edición expiró recientemente';
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

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final base = kIsWeb ? 'https://geocode.maps.co' : 'https://nominatim.openstreetmap.org';
      final uri = Uri.parse('$base/reverse?format=jsonv2&lat=$lat&lon=$lng');
      final res = await http.get(uri, headers: {'User-Agent': 'safearea-app/1.0'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hoursSinceCreation = now.difference(widget.report.createdAt).inHours;
    final canEdit = hoursSinceCreation <= 24;
    final reportService = Provider.of<ReportService>(context);
    
    // Calcular cuándo expiró el plazo de edición
    final expirationTime = widget.report.createdAt.add(const Duration(hours: 24));
    final hoursSinceExpiration = now.difference(expirationTime).inHours;
    final daysSinceExpiration = now.difference(expirationTime).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Reporte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!canEdit)
                Card(
                  color: Colors.amberAccent,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Este reporte ya no puede ser editado (límite de 24 horas).',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Creado: ${_formatDateTime(widget.report.createdAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          expirationTime.isBefore(now)
                              ? _getExpirationMessage(daysSinceExpiration, hoursSinceExpiration)
                              : 'Puedes editar hasta: ${expirationTime.day}/${expirationTime.month}/${expirationTime.year} a las ${expirationTime.hour.toString().padLeft(2, '0')}:${expirationTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              // Tipo de Reporte
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
              const SizedBox(height: 16),

              // Título
              AuthTextField(
                label: 'Título del Reporte',
                icon: Icons.title,
                controller: _titleController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

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
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

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
                                        final pretty = await _reverseGeocode(
                                          picked.latitude,
                                          picked.longitude,
                                        );
                                        _locationController.text =
                                            pretty ?? '${picked.latitude},${picked.longitude}';
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
              const SizedBox(height: 32),

              LoadingButton(
                text: 'Actualizar Reporte',
                onPressed: canEdit
                    ? _updateReport
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edición no permitida después de 24 horas')),
                        );
                      },
                isLoading: reportService.isLoading,
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