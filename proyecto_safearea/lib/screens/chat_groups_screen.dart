import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/chat_group_model.dart';
import 'chat_screen.dart';

class ChatGroupsScreen extends StatelessWidget {
  const ChatGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos de Chat'),
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                tabs: const [
                  Tab(text: 'Zonas'),
                  Tab(text: 'Mis Grupos'),
                ],
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab de ZONAS PREDEFINIDAS
                  StreamBuilder(
                    stream: chatService.predefinedZonesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      
                      // Ordenar zonas según el orden predefinido
                      final zoneIds = ['zona_centro', 'zona_sur', 'zona_norte'];
                      docs.sort((a, b) {
                        final aIndex = zoneIds.indexOf(a.id);
                        final bIndex = zoneIds.indexOf(b.id);
                        if (aIndex == -1) return 1;
                        if (bIndex == -1) return -1;
                        return aIndex.compareTo(bIndex);
                      });
                      
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Zonas de Tacna',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Las zonas se están cargando...',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
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
                          return _ZoneCard(
                            group: group,
                            isMember: isMember,
                            onTap: () async {
                              // Si no es miembro, unirse primero
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
                              }
                              // Navegar al chat del grupo
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
                                        title: const Text('Salir de la zona'),
                                        content: Text(
                                          '¿Deseas salir de "${group.name}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
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
                                      if (error != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(error)),
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
                  // Tab de mis grupos
                  StreamBuilder(
                    stream: chatService.myGroupsStream(
                      authService.currentUser?.id ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No estás en ninguna zona',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Únete a una zona para empezar a chatear',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      // Ordenar en memoria: primero zonas predefinidas, luego por nombre
                      final zoneIds = ['zona_centro', 'zona_sur', 'zona_norte'];
                      docs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aId = a.id;
                        final bId = b.id;
                        
                        // Prioridad a zonas predefinidas
                        final aIsZone = zoneIds.contains(aId);
                        final bIsZone = zoneIds.contains(bId);
                        if (aIsZone && !bIsZone) return -1;
                        if (!aIsZone && bIsZone) return 1;
                        if (aIsZone && bIsZone) {
                          // Ordenar zonas por orden predefinido
                          final aIndex = zoneIds.indexOf(aId);
                          final bIndex = zoneIds.indexOf(bId);
                          return aIndex.compareTo(bIndex);
                        }
                        // Ordenar otros grupos por nombre
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
                          // Determinar si es una zona predefinida
                          final isPredefinedZone = zoneIds.contains(docs[index].id);
                          return isPredefinedZone
                              ? _ZoneCard(
                                  group: group,
                                  isMember: true,
                                  onTap: () {
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
                                  onLongPress: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Salir de la zona'),
                                        content: Text(
                                          '¿Deseas salir de "${group.name}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
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
                                      if (error != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(error)),
                                        );
                                      }
                                    }
                                  },
                                )
                              : _GroupCard(
                            group: group,
                            isMember: true,
                            onTap: () {
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
                            onLongPress: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Salir del grupo'),
                                  content: Text(
                                    '¿Deseas salir del grupo "${group.name}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
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
                                if (error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Botón de crear grupo oculto - Solo se permiten zonas predefinidas
    );
  }
}

/// Card para zonas predefinidas (destacado)
class _ZoneCard extends StatelessWidget {
  final ChatGroup group;
  final bool isMember;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ZoneCard({
    required this.group,
    required this.isMember,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary,
          width: 2,
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
              // Avatar de zona con icono de ubicación
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.location_on,
                    color: colorScheme.onPrimary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información de la zona
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
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        if (isMember) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Miembro',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final chatService = Provider.of<ChatService>(context, listen: false);
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Salir de la zona'),
                                  content: Text('¿Deseas salir de "${group.name}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final err = await chatService.leaveGroup(
                                  groupId: group.id,
                                  userId: authService.currentUser!.id,
                                );
                                if (context.mounted && err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.logout, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text('Salir', style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ]
                        else ...[
                          InkWell(
                            onTap: () async {
                              final chatService = Provider.of<ChatService>(context, listen: false);
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final err = await chatService.joinGroup(
                                groupId: group.id,
                                userId: authService.currentUser!.id,
                              );
                              if (context.mounted) {
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Te uniste a "${group.name}"')),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.person_add_alt, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text('Unirme', style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.members.length} miembros',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Zona Oficial',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ChatGroup group;
  final bool isMember;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _GroupCard({
    required this.group,
    required this.isMember,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
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
              // Avatar del grupo
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.group,
                    color: colorScheme.onPrimary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del grupo
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
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isMember) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Miembro',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final chatService = Provider.of<ChatService>(context, listen: false);
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Salir del grupo'),
                                  content: Text('¿Deseas salir de "${group.name}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final err = await chatService.leaveGroup(
                                  groupId: group.id,
                                  userId: authService.currentUser!.id,
                                );
                                if (context.mounted && err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.logout, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text('Salir', style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ]
                        else ...[
                          InkWell(
                            onTap: () async {
                              final chatService = Provider.of<ChatService>(context, listen: false);
                              final authService = Provider.of<AuthService>(context, listen: false);
                              final err = await chatService.joinGroup(
                                groupId: group.id,
                                userId: authService.currentUser!.id,
                              );
                              if (context.mounted) {
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Te uniste a "${group.name}"')),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.person_add_alt, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text('Unirme', style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.members.length} miembros',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          group.isPublic
                              ? Icons.public
                              : Icons.lock_outline,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          group.isPublic ? 'Público' : 'Privado',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

