import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // RF-16: Cambiar estado activo/inactivo de un usuario
  Future<void> _toggleUserStatus(BuildContext context, String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': !currentStatus,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus 
                ? 'Usuario desactivado' 
                : 'Usuario activado',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar estado: $e')),
      );
    }
  }

  // Cambiar rol de un usuario (solo administradores)
  Future<void> _changeUserRole(BuildContext context, String userId, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    final authService = Provider.of<AuthService>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cambiar Rol'),
          content: Text(
            '¿Deseas cambiar el rol de este usuario a "${newRole == 'admin' ? 'Administrador' : 'Usuario'}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Cambiar',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final error = await authService.changeUserRole(userId, newRole);
      if (!context.mounted) return;
      
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rol cambiado a ${newRole == 'admin' ? 'Administrador' : 'Usuario'}',
            ),
            backgroundColor: Colors.green,
          ),
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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    // RF-16: Solo administradores pueden acceder a la Gestión de Usuarios
    if (currentUser == null || !currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Usuarios'),
          elevation: 0,
        ),
        body: const _AccessDeniedWidget(
          message: 'Solo los administradores pueden gestionar usuarios.',
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No hay usuarios'));
          }

          // RF-16: Separar usuarios activos e inactivos
          final activeUsers = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final inactiveUsers = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (final doc in docs) {
            final data = doc.data();
            final isActive = data['isActive'] ?? true;
            if (isActive) {
              activeUsers.add(doc);
            } else {
              inactiveUsers.add(doc);
            }
          }

          // Ordenar alfabéticamente por nombre dentro de cada lista
          int compareByName(
            QueryDocumentSnapshot<Map<String, dynamic>> a,
            QueryDocumentSnapshot<Map<String, dynamic>> b,
          ) {
            final da = a.data();
            final db = b.data();
            final nameA = (da['name'] as String? ?? '').toLowerCase();
            final nameB = (db['name'] as String? ?? '').toLowerCase();
            return nameA.compareTo(nameB);
          }

          activeUsers.sort(compareByName);
          inactiveUsers.sort(compareByName);

          // Aplicar filtro de búsqueda por nombre o email (case-insensitive)
          List<QueryDocumentSnapshot<Map<String, dynamic>>> applySearch(
            List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
          ) {
            if (_searchQuery.trim().isEmpty) return list;
            final q = _searchQuery.toLowerCase();
            return list.where((doc) {
              final data = doc.data();
              final name = (data['name'] as String? ?? '').toLowerCase();
              final email = (data['email'] as String? ?? '').toLowerCase();
              return name.contains(q) || email.contains(q);
            }).toList();
          }

          final filteredActive = applySearch(activeUsers);
          final filteredInactive = applySearch(inactiveUsers);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre o correo...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Usuarios activos
              if (filteredActive.isNotEmpty) ...[
                Text(
                  'Usuarios Activos (${filteredActive.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...filteredActive.map((doc) => _buildUserTile(
                  context: context,
                  doc: doc,
                  currentUser: currentUser,
                  onToggleStatus: _toggleUserStatus,
                  colorScheme: colorScheme,
                  theme: theme,
                )),
                const SizedBox(height: 24),
              ],

              // Usuarios inactivos
              if (filteredInactive.isNotEmpty) ...[
                Text(
                  'Usuarios Inactivos (${filteredInactive.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...filteredInactive.map((doc) => _buildUserTile(
                  context: context,
                  doc: doc,
                  currentUser: currentUser,
                  onToggleStatus: _toggleUserStatus,
                  colorScheme: colorScheme,
                  theme: theme,
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildUserTile({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserModel? currentUser,
    required Function(BuildContext, String, bool) onToggleStatus,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final u = doc.data();
    final userId = doc.id;
    final isActive = u['isActive'] ?? true;
    final role = u['role'] ?? 'user';
    final isCurrentUser = currentUser?.id == userId;
    final isAdmin = currentUser?.isAdmin ?? false;

    // Presencia en línea basada en isOnline y lastSeen
    final rawIsOnline = u['isOnline'] == true;
    final lastSeenRaw = u['lastSeen'];
    DateTime? lastSeen;
    if (lastSeenRaw is Timestamp) {
      lastSeen = lastSeenRaw.toDate();
    } else if (lastSeenRaw is String) {
      lastSeen = DateTime.tryParse(lastSeenRaw);
    }
    bool isOnline = false;
    if (rawIsOnline && lastSeen != null) {
      final diff = DateTime.now().difference(lastSeen);
      // Considerar en línea si la última actividad fue en los últimos 3 minutos
      isOnline = diff.inMinutes < 3;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive 
          ? colorScheme.surface 
          : colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: (u['profileImage'] != null && 
                  (u['profileImage'] as String).isNotEmpty)
                  ? NetworkImage(u['profileImage'])
                  : null,
              child: (u['profileImage'] == null || 
                  (u['profileImage'] as String).isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
            // RF-16: Indicador de estado
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                u['name'] ?? 'Usuario',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: isActive ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (role == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u['email'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'Activo' : 'Inactivo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: isOnline ? Colors.lightGreen : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'En línea' : 'Desconectado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOnline ? Colors.lightGreen : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Tocar el usuario abre un chat privado (solo texto) si no es uno mismo
        onTap: !isCurrentUser
            ? () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                final me = authService.currentUser;
                if (me == null) return;

                final chatService = Provider.of<ChatService>(context, listen: false);
                final chatId = await chatService.openOrCreatePrivateChat(
                  currentUserId: me.id,
                  currentUserName: me.name,
                  otherUserId: userId,
                  otherUserName: (u['name'] as String?) ?? 'Usuario',
                );

                if (!context.mounted || chatId == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      groupId: chatId,
                      groupName: (u['name'] as String?) ?? 'Chat privado',
                    ),
                  ),
                );
              }
            : null,
        trailing: !isCurrentUser && isAdmin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón para cambiar rol
                  IconButton(
                    icon: Icon(
                      role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                      color: role == 'admin' 
                          ? colorScheme.primary 
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: role == 'admin' 
                        ? 'Quitar privilegios de administrador' 
                        : 'Hacer administrador',
                    onPressed: () => _changeUserRole(context, userId, role),
                  ),
                  // Botón para cambiar estado
                  IconButton(
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      color: isActive ? Colors.orange : Colors.green,
                    ),
                    tooltip: isActive ? 'Desactivar usuario' : 'Activar usuario',
                    onPressed: () => onToggleStatus(context, userId, isActive),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// Widget para mostrar acceso denegado
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

