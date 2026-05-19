import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/location_service.dart';
import '../models/chat_group_model.dart';
import 'chat_screen.dart';

class DistrictChatScreen extends StatefulWidget {
  const DistrictChatScreen({super.key});

  @override
  State<DistrictChatScreen> createState() => _DistrictChatScreenState();
}

class _DistrictChatScreenState extends State<DistrictChatScreen> {
  bool _isLoadingLocation = false;
  String? _detectedDistrictId;
  String? _detectedDistrictName;
  bool _autoJoined = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Inicializar zonas predefinidas
    final chatService = Provider.of<ChatService>(context, listen: false);
    await chatService.initializePredefinedZones();
    
    setState(() {
      _isInitializing = false;
    });
    
    // Detectar y unirse automáticamente
    await _detectAndJoinDistrict();
  }

  // 1. Detectar zona del usuario por ubicación
  Future<void> _detectAndJoinDistrict() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        _showLocationError();
        return;
      }

      final chatService = Provider.of<ChatService>(context, listen: false);
      final district = await chatService.detectDistrictByLocation();

      if (district != null) {
        setState(() {
          _detectedDistrictId = district['id'];
          _detectedDistrictName = district['name'];
        });

        // 2. Unir usuario a sala de chat correspondiente
        await _autoJoinDistrict(district);
      } else {
        _showNoDistrictFound();
      }
    } catch (e) {
      debugPrint('Error detectando distrito: $e');
      _showLocationError();
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _autoJoinDistrict(Map<String, dynamic> district) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    final error = await chatService.autoJoinDistrict(authService.currentUser!.id);
    
    if (error == null && mounted) {
      setState(() {
        _autoJoined = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Te has unido al chat de ${district['name']} automáticamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo detectar tu ubicación. Activa el GPS y los permisos de ubicación.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showNoDistrictFound() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se detectó un distrito específico. Puedes unirte manualmente a cualquier chat.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat por Distritos - Tacna'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Detectar mi distrito',
            onPressed: _detectAndJoinDistrict,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de distrito detectado
          if (_detectedDistrictName != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tu ubicación detectada',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Distrito: $_detectedDistrictName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_autoJoined)
                    const Chip(
                      label: Text('Unido'),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),

          // Indicador de carga de ubicación
          if (_isLoadingLocation)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Detectando tu ubicación...',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

          // Lista de distritos
          Expanded(
            child: StreamBuilder(
              stream: chatService.predefinedZonesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _initializeChat(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No hay distritos disponibles',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Ordenar distritos por nombre
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aName = aData['name'] as String? ?? '';
                  final bName = bData['name'] as String? ?? '';
                  return aName.compareTo(bName);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final group = ChatGroup.fromMap(
                      docs[index].data() as Map<String, dynamic>,
                    );
                    final isMember = group.members.contains(
                      authService.currentUser?.id,
                    );
                    final isDetected = group.id == _detectedDistrictId;
                    
                    return _DistrictCard(
                      group: group,
                      isMember: isMember,
                      isDetected: isDetected,
                      onTap: () async {
                        // Unirse si no es miembro
                        if (!isMember) {
                          final error = await chatService.joinGroup(
                            groupId: group.id,
                            userId: authService.currentUser!.id,
                          );
                          if (!context.mounted) return;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Te uniste a ${group.name}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        // Navegar al chat
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              groupId: group.id,
                              groupName: group.name,
                            ),
                          ),
                        );
                      },
                      onLongPress: isMember
                          ? () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Salir del chat'),
                                  content: Text('¿Deseas salir del chat de "${group.name}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Salir'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                final error = await chatService.leaveGroup(
                                  groupId: group.id,
                                  userId: authService.currentUser!.id,
                                );
                                if (!context.mounted) return;
                                if (error == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Saliste de ${group.name}'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error ?? 'Error al salir')),
                                  );
                                }
                              }
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para cada distrito
class _DistrictCard extends StatelessWidget {
  final ChatGroup group;
  final bool isMember;
  final bool isDetected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DistrictCard({
    required this.group,
    required this.isMember,
    required this.isDetected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Colores para cada distrito basado en el ID
    Color getDistrictColor(String id) {
      final colors = {
        'distrito_tacna': Colors.blue,
        'distrito_alto_alianza': Colors.teal,
        'distrito_calana': Colors.brown,
        'distrito_ciudad_nueva': Colors.cyan,
        'distrito_coronel_albarracin': Colors.purple,
        'distrito_inclan': Colors.indigo,
        'distrito_pachia': Colors.lightGreen,
        'distrito_palca': Colors.amber,
        'distrito_pocollay': Colors.orange,
        'distrito_sama': Colors.deepOrange,
        'distrito_yarada': Colors.red,
      };
      return colors[id] ?? colorScheme.primary;
    }

    final districtColor = getDistrictColor(group.id);

    return Card(
      elevation: isMember ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isMember 
          ? districtColor.withValues(alpha: 0.1)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDetected 
              ? districtColor 
              : (isMember ? districtColor : colorScheme.outlineVariant),
          width: isDetected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar del distrito
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [districtColor, districtColor.withValues(alpha: 0.7)],
                  ),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _getDistrictIcon(group.id),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Información del distrito
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isMember ? districtColor : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isDetected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: districtColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'TU ZONA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${group.members.length} miembros',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          isMember ? Icons.check_circle : Icons.add_circle_outline,
                          size: 14,
                          color: isMember ? Colors.green : districtColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isMember ? 'Miembro' : 'Unirse',
                          style: textTheme.bodySmall?.copyWith(
                            color: isMember ? Colors.green : districtColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: districtColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDistrictIcon(String id) {
    switch (id) {
      case 'distrito_tacna':
        return Icons.location_city;
      case 'distrito_alto_alianza':
        return Icons.terrain;
      case 'distrito_calana':
        return Icons.landscape;
      case 'distrito_ciudad_nueva':
        return Icons.apartment;
      case 'distrito_coronel_albarracin':
        return Icons.flag;
      case 'distrito_inclan':
        return Icons.nature_people;
      case 'distrito_pachia':
        return Icons.park;
      case 'distrito_palca':
        return Icons.terrain;
      case 'distrito_pocollay':
        return Icons.grass;
      case 'distrito_sama':
        return Icons.beach_access;
      case 'distrito_yarada':
        return Icons.water;
      default:
        return Icons.location_on;
    }
  }
}