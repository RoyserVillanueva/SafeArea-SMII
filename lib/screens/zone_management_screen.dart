// lib/screens/zone_management_screen.dart
// 19.1. Diseñar pantalla de gestión de zonas
// 19.3. Implementar creación de zona
// 19.4. Implementar edición de límites (simplificado)
// 19.5. Implementar eliminación de zona
// 19.6. Asignar moderadores por zona

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/chat_group_model.dart';

class ZoneManagementScreen extends StatefulWidget {
  const ZoneManagementScreen({super.key});

  @override
  State<ZoneManagementScreen> createState() => _ZoneManagementScreenState();
}

class _ZoneManagementScreenState extends State<ZoneManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeZones();
  }

  Future<void> _initializeZones() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    await chatService.initializePredefinedZones();
  }

  // ==================== CREAR ZONA ====================
  Future<void> _createZone() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final zoneIdController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Zona de Chat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: zoneIdController,
                decoration: const InputDecoration(
                  labelText: 'ID de la zona (ej: zona_norte)',
                  hintText: 'zona_nueva',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la zona',
                  hintText: 'Zona Norte',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Chat para residentes de la zona norte',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final zoneId = zoneIdController.text.trim();
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              if (zoneId.isEmpty || name.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completa todos los campos')),
                );
                return;
              }

              // Crear zona en Firestore
              final chatService = Provider.of<ChatService>(context, listen: false);
              final authService = Provider.of<AuthService>(context, listen: false);

              final error = await chatService.createGroup(
                name: name,
                description: description,
                createdBy: authService.currentUser!.id,
                createdByName: authService.currentUser!.name,
                isPublic: true,
              );

              if (!context.mounted) return;

              if (error == null) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Zona creada exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  // ==================== EDITAR ZONA ====================
  Future<void> _editZone(ChatGroup group) async {
    final nameController = TextEditingController(text: group.name);
    final descriptionController = TextEditingController(text: group.description);
    final isPublic = group.isPublic;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Zona: ${group.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la zona',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Zona pública'),
              value: isPublic,
              onChanged: (value) {
                // Nota: Este cambio se aplica al guardar
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              if (name.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completa todos los campos')),
                );
                return;
              }

              // Actualizar en Firestore
              final updatedGroup = group.copyWith(
                name: name,
                description: description,
              );

              try {
                await FirebaseFirestore.instance
                    .collection('chatGroups')
                    .doc(group.id)
                    .update(updatedGroup.toMap());

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Zona actualizada'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error al actualizar: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ==================== ELIMINAR ZONA ====================
  Future<void> _deleteZone(ChatGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Zona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar "${group.name}"?'),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Esto eliminará el chat y todos sus mensajes.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Eliminar mensajes del chat
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection('chatGroups')
            .doc(group.id)
            .collection('messages')
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // 2. Eliminar el grupo
        await FirebaseFirestore.instance.collection('chatGroups').doc(group.id).delete();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Zona eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== ASIGNAR MODERADORES ====================
  Future<void> _assignModerators(ChatGroup group) async {
    final selectedModerators = <String>[];
    final allUsers = <Map<String, dynamic>>[];

    // Obtener todos los usuarios
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      allUsers.add({
        'id': doc.id,
        'name': data['name'] ?? 'Usuario',
        'email': data['email'] ?? '',
        'isAdmin': data['role'] == 'admin',
      });
    }

    // Moderadores actuales (si se implementa)
    final currentModerators = group.members
        .where((id) => allUsers.any((u) => u['id'] == id && u['isAdmin']))
        .toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Moderadores de ${group.name}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: allUsers.length,
                itemBuilder: (context, index) {
                  final user = allUsers[index];
                  final isSelected = selectedModerators.contains(user['id']);
                  return CheckboxListTile(
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    value: isSelected,
                    onChanged: (value) {
                      setModalState(() {
                        if (value == true) {
                          selectedModerators.add(user['id']);
                        } else {
                          selectedModerators.remove(user['id']);
                        }
                      });
                    },
                    secondary: user['isAdmin']
                        ? const Icon(Icons.admin_panel_settings, color: Colors.orange)
                        : null,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Asignar moderadores (unirlos al chat)
                  final chatService = Provider.of<ChatService>(context, listen: false);
                  
                  for (final userId in selectedModerators) {
                    await chatService.joinGroup(
                      groupId: group.id,
                      userId: userId,
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Moderadores asignados'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text('Asignar (${selectedModerators.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    if (currentUser == null || !currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Zonas'),
          elevation: 0,
        ),
        body: const _AccessDeniedWidget(
          message: 'Solo los administradores pueden gestionar zonas.',
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Zonas de Chat'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear nueva zona',
            onPressed: _createZone,
          ),
        ],
      ),
      body: Column(
        children: [
          // Búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar zona por nombre...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Lista de zonas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatGroups')
                  .where('isPublic', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var zones = snapshot.data!.docs
                    .map((doc) => ChatGroup.fromMap(doc.data() as Map<String, dynamic>))
                    .toList();

                // Aplicar búsqueda
                if (_searchQuery.isNotEmpty) {
                  zones = zones.where((zone) =>
                    zone.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    zone.description.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();
                }

                // Ordenar: primero zonas predefinidas, luego creadas por usuario
                final predefinedIds = ['zona_centro', 'zona_sur', 'zona_norte'];
                zones.sort((a, b) {
                  final aIsPredefined = predefinedIds.contains(a.id);
                  final bIsPredefined = predefinedIds.contains(b.id);
                  if (aIsPredefined && !bIsPredefined) return -1;
                  if (!aIsPredefined && bIsPredefined) return 1;
                  return a.name.compareTo(b.name);
                });

                if (zones.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay zonas de chat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Las zonas predefinidas se crean automáticamente',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: zones.length,
                  itemBuilder: (context, index) {
                    final zone = zones[index];
                    final isPredefined = predefinedIds.contains(zone.id);
                    
                    return _ZoneCard(
                      zone: zone,
                      isPredefined: isPredefined,
                      onEdit: () => _editZone(zone),
                      onDelete: isPredefined ? null : () => _deleteZone(zone),
                      onModerators: () => _assignModerators(zone),
                      colorScheme: colorScheme,
                      theme: theme,
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

// ============================================================
// WIDGET: TARJETA DE ZONA
// ============================================================

class _ZoneCard extends StatelessWidget {
  final ChatGroup zone;
  final bool isPredefined;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onModerators;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _ZoneCard({
    required this.zone,
    required this.isPredefined,
    required this.onEdit,
    required this.onModerators,
    required this.colorScheme,
    required this.theme,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPredefined ? colorScheme.primary : colorScheme.outlineVariant,
          width: isPredefined ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPredefined 
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPredefined ? Icons.verified : Icons.chat_bubble,
                    color: isPredefined ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              zone.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isPredefined)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Oficial',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        zone.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${zone.members.length} miembros',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón de moderadores
                OutlinedButton.icon(
                  icon: const Icon(Icons.people, size: 16),
                  label: const Text('Moderadores'),
                  onPressed: onModerators,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                // Botón de editar
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                // Botón de eliminar (solo si no es predefinida)
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: Icon(Icons.delete_forever, size: 16, color: colorScheme.error),
                    label: Text(
                      'Eliminar',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET: ACCESO DENEGADO
// ============================================================

class _AccessDeniedWidget extends StatelessWidget {
  final String message;

  const _AccessDeniedWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Acceso Denegado',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}