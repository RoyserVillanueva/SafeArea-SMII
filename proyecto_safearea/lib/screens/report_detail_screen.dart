import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';
import 'edit_report_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Report _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'activo':
        return Colors.orange;
      case 'en_proceso':
        return Colors.blue;
      case 'resuelto':
        return Colors.green;
      default:
        return Colors.grey;
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  // 8.4 Integrar mapa con ubicacion del incidente
  String _maskedLocation(String location) {
    final noDigits = location.replaceAll(RegExp(r'[0-9]'), '');
    final parts = noDigits.split(',');
    if (parts.length <= 1) return noDigits.trim();
    return parts.sublist(parts.length - 2).join(',').trim();
  }

  Widget _buildStatusButton(
    BuildContext context,
    String status,
    ReportService reportService,
  ) {
    return OutlinedButton(
      onPressed: _report.status == status
          ? null
          : () async {
              final error = await reportService.changeReportStatus(_report.id, status);
              if (error != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                }
              } else {
                if (mounted) {
                  setState(() {
                    _report = _report.copyWith(status: status);
                  });
                }
              }
            },
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          // Siempre usar naranja para el estado seleccionado
          color: _report.status == status 
              ? Colors.orange 
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        backgroundColor: _report.status == status 
            ? Colors.orange.withValues(alpha: 0.1) 
            : null,
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          // Texto naranja cuando está seleccionado
          color: _report.status == status 
              ? Colors.orange 
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final reportService = Provider.of<ReportService>(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bool isOwner = authService.currentUser?.id == _report.userId;

    final bool isAdmin = authService.currentUser?.isAdmin ?? false;
    // RF-17: Los administradores pueden moderar cualquier reporte
    final bool canModerate = isAdmin || isOwner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Reporte'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditReportScreen(report: _report),
                  ),
                );
              },
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Eliminar reporte'),
                    content: const Text('¿Deseas eliminar este reporte?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final err = await reportService.softDeleteReport(_report.id);
                  if (context.mounted) {
                    if (err == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reporte eliminado')),
                      );
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Header con tipo y estado
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _getStatusColor(_report.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getStatusColor(_report.status)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      _report.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(_report.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      _getTypeLabel(_report.type).toUpperCase(),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Título
            Text(
              _report.title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Fecha
            Text(
              'Reportado el ${_formatDate(_report.createdAt)}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // 8.4 Integrar mapa con Ubicación del incidente
            ListTile(
              leading: Icon(Icons.location_on, color: colorScheme.error),
              title: const Text('Ubicación'),
              subtitle: Text(isOwner ? _report.location : _maskedLocation(_report.location)),
            ),
            if (_report.latitude != null && _report.longitude != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(_report.latitude!, _report.longitude!),
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.safearea.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_report.latitude!, _report.longitude!),
                            width: 40,
                            height: 40,
                            child: Icon(Icons.location_pin, size: 40, color: colorScheme.error),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(),

            // Descripción
            ListTile(
              leading: Icon(Icons.description, color: colorScheme.primary),
              title: const Text('Descripción'),
              subtitle: Text(_report.description),
            ),
            const Divider(),

            // RF-11: Imágenes
            // 8.3. Implementar galería de imágenes
            // Implementando la galería de imágenes en el reporte
            if (_report.images.isNotEmpty) ...[
              Text(
                'Imágenes (${_report.images.length})',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _report.images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () {
                            // Mostrar imagen en pantalla completa
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _FullScreenImage(imageUrl: _report.images[index]),
                              ),
                            );
                          },
                          child: Image.network(
                            _report.images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],

            // Información adicional
            ListTile(
              leading: Icon(Icons.info, color: colorScheme.tertiary),
              title: const Text('ID del Reporte'),
              subtitle: Text(_report.id),
            ),
            const Divider(),

            // RF-17: Gestión de estados - Moderación (admins pueden moderar cualquier reporte)
            if (canModerate) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Cambiar Estado:',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isAdmin && !isOwner) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Moderación',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildStatusButton(context, 'activo', reportService),
                  _buildStatusButton(context, 'en_proceso', reportService),
                  _buildStatusButton(context, 'resuelto', reportService),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// Widget para mostrar imagen en pantalla completa
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}