// 17.4. Agregar opción eliminar usuario
// 17.5. Registrar acciones en logs
// 17.6. Notificar al usuario afectado

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

  // ==================== TAREA 3: BLOQUEAR/DESBLOQUEAR ====================
  Future<void> _toggleUserStatus(BuildContext context, String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': !currentStatus,
      });
      
      // TAREA 5: Registrar acción en logs
      _logAction(
        action: currentStatus ? 'desactivar' : 'activar',
        userId: userId,
        details: 'Usuario ${currentStatus ? 'desactivado' : 'activado'}',
      );
      
      // TAREA 6: Notificar al usuario afectado
      await _notifyUser(userId, currentStatus ? 'Cuenta desactivada' : 'Cuenta activada');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus 
                ? '✅ Usuario desactivado' 
                : '✅ Usuario activado',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al cambiar estado: $e')),
      );
    }
  }

  // ==================== TAREA 4: ELIMINAR USUARIO ====================
  Future<void> _deleteUser(BuildContext context, String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Usuario'),
          content: Text(
            '¿Estás seguro de eliminar a "$userName"?\n\n'
            '⚠️ Esta acción es irreversible y eliminará:\n'
            '• Todos los reportes del usuario\n'
            '• Todos los mensajes del usuario\n'
            '• La cuenta del usuario permanentemente',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Mostrar diálogo de carga
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Eliminando usuario...'),
              ],
            ),
          ),
        );

        // 1. Eliminar reportes del usuario
        final reportsSnapshot = await FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: userId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in reportsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // 2. Eliminar mensajes del usuario en todos los grupos
        // Buscar mensajes del usuario en todos los grupos usando collectionGroup
        final messagesSnapshot = await FirebaseFirestore.instance
            .collectionGroup('messages')
            .where('userId', isEqualTo: userId)
            .get();

        final batch2 = FirebaseFirestore.instance.batch();
        for (final doc in messagesSnapshot.docs) {
          batch2.delete(doc.reference);
        }
        await batch2.commit();

        // 3. Eliminar el documento del usuario
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();

        // TAREA 5: Registrar acción en logs
        _logAction(
          action: 'eliminar',
          userId: userId,
          details: 'Usuario $userName eliminado permanentemente',
        );

        // Cerrar diálogo de carga
        if (context.mounted) Navigator.pop(context);
        
        // Mostrar mensaje de éxito
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario "$userName" eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (context.mounted) Navigator.pop(context);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== TAREA 5: REGISTRAR ACCIONES EN LOGS ====================
  void _logAction({
    required String action,
    required String userId,
    required String details,
  }) {
    // Guardar en Firestore (colección de logs)
    FirebaseFirestore.instance.collection('admin_logs').add({
      'action': action,
      'userId': userId,
      'adminId': Provider.of<AuthService>(context, listen: false).currentUser?.id,
      'adminName': Provider.of<AuthService>(context, listen: false).currentUser?.name,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    }).then((_) {
      debugPrint('📝 Log registrado: $action - $details');
    }).catchError((e) {
      debugPrint('❌ Error registrando log: $e');
    });
  }

  // ==================== TAREA 6: NOTIFICAR AL USUARIO AFECTADO ====================
  Future<void> _notifyUser(String userId, String message) async {
    try {
      // Crear notificación en Firestore para el usuario
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
        'title': 'Actualización de cuenta',
        'body': message,
        'type': 'account_update',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('📨 Notificación enviada al usuario $userId: $message');
    } catch (e) {
      debugPrint('❌ Error enviando notificación: $e');
    }
  }

  // ==================== CAMBIAR ROL ====================
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
        // TAREA 5: Registrar acción
        _logAction(
          action: 'cambiar_rol',
          userId: userId,
          details: 'Rol cambiado a $newRole',
        );
        
        // TAREA 6: Notificar al usuario
        await _notifyUser(userId, 'Tu rol ha sido cambiado a ${newRole == 'admin' ? "Administrador" : "Usuario"}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Rol cambiado a ${newRole == 'admin' ? 'Administrador' : 'Usuario'}',
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

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
        actions: [
          // Botón para ver logs de administración
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver logs de administración',
            onPressed: () => _showAdminLogs(),
          ),
        ],
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
                  onDeleteUser: _deleteUser,
                  colorScheme: colorScheme,
                  theme: theme,
                )),
                const SizedBox(height: 24),
              ],

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
                  onDeleteUser: _deleteUser,
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

  // ==================== VER LOGS DE ADMINISTRACIÓN ====================
  void _showAdminLogs() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.maxFinite,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '📝 Logs de Administración',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('admin_logs')
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final logs = snapshot.data!.docs;
                    if (logs.isEmpty) {
                      return const Center(child: Text('No hay logs registrados'));
                    }
                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final data = logs[index].data() as Map<String, dynamic>;
                        final action = data['action'] ?? '';
                        final details = data['details'] ?? '';
                        final adminName = data['adminName'] ?? 'Sistema';
                        final timestamp = data['timestamp'] as Timestamp?;
                        final date = timestamp?.toDate().toString().substring(0, 19) ?? 'Fecha desconocida';
                        
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _getLogIcon(action),
                            color: _getLogColor(action),
                          ),
                          title: Text(
                            '$action: $details',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '👤 $adminName • $date',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getLogIcon(String action) {
    switch (action) {
      case 'activar': return Icons.check_circle;
      case 'desactivar': return Icons.block;
      case 'eliminar': return Icons.delete_forever;
      case 'cambiar_rol': return Icons.admin_panel_settings;
      default: return Icons.info;
    }
  }

  Color _getLogColor(String action) {
    switch (action) {
      case 'activar': return Colors.green;
      case 'desactivar': return Colors.orange;
      case 'eliminar': return Colors.red;
      case 'cambiar_rol': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== WIDGET: TARJETA DE USUARIO ====================
  Widget _buildUserTile({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required UserModel? currentUser,
    required Function(BuildContext, String, bool) onToggleStatus,
    required Function(BuildContext, String, String) onDeleteUser,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final u = doc.data();
    final userId = doc.id;
    final isActive = u['isActive'] ?? true;
    final role = u['role'] ?? 'user';
    final isCurrentUser = currentUser?.id == userId;
    final isAdmin = currentUser?.isAdmin ?? false;

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
      isOnline = diff.inMinutes < 3;
    }

    final userName = u['name'] ?? 'Usuario';

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
                userName,
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
                const SizedBox(width: 12),
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
                  otherUserName: userName,
                );

                if (!context.mounted || chatId == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      groupId: chatId,
                      groupName: 'Chat con $userName',
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
                  // Botón para cambiar estado (bloquear/desbloquear)
                  IconButton(
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      color: isActive ? Colors.orange : Colors.green,
                    ),
                    tooltip: isActive ? 'Desactivar usuario' : 'Activar usuario',
                    onPressed: () => onToggleStatus(context, userId, isActive),
                  ),
                  // 🆕 TAREA 4: Botón para eliminar usuario
                  IconButton(
                    icon: Icon(
                      Icons.delete_forever,
                      color: colorScheme.error,
                    ),
                    tooltip: 'Eliminar usuario permanentemente',
                    onPressed: () => onDeleteUser(context, userId, userName),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// ==================== WIDGET: ACCESO DENEGADO ====================

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