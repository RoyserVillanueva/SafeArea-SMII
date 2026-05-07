import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Widget optimizado para mostrar un mensaje de chat
class _ChatMessageBubble extends StatelessWidget {
  final String text;
  final String? userName;
  final bool isMine;
  final String? timeLabel; // HH:mm
  final String? imageUrl; // RF-11: URL de imagen
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ChatMessageBubble({
    required this.text,
    this.userName,
    required this.isMine,
    this.timeLabel,
    this.imageUrl, // RF-11: URL de imagen
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isMine ? 40 : 12,
        right: isMine ? 12 : 40,
        top: 6,
        bottom: 6,
      ),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        gradient: isMine
            ? LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              )
            : null,
        color: isMine ? null : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMine ? 20 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine && userName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  userName!,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // RF-11: Mostrar imagen si existe
            if (imageUrl != null && imageUrl!.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  // Mostrar imagen en pantalla completa
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _FullScreenImage(imageUrl: imageUrl!),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: 200,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
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
                      return Container(
                        width: 200,
                        height: 200,
                        color: colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (text.isNotEmpty) const SizedBox(height: 8),
            ],
            // Mostrar texto si existe
            if (text.isNotEmpty)
              Text(
                text,
                style: textTheme.bodyMedium?.copyWith(
                  color: isMine ? colorScheme.onPrimary : colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            if (timeLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: isMine
                          ? colorScheme.onPrimary.withValues(alpha: 0.85)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
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

class ChatScreen extends StatefulWidget {
  final String? groupId;
  final String? groupName;

  const ChatScreen({
    super.key,
    this.groupId,
    this.groupName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Establecer el grupo actual en el servicio
    if (widget.groupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chat = Provider.of<ChatService>(context, listen: false);
        chat.setCurrentGroup(widget.groupId);
      });
    }
  }

  Future<void> _sendImage() async {
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
    final storageService = StorageService();
    final image = await storageService.pickImage(source: source);
    if (image == null || !mounted) return;

    // Subir imagen
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageUrl = await storageService.uploadImageFile(
        file: image,
        folder: 'chat',
      );

      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });

      if (imageUrl == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir imagen')),
        );
        return;
      }

      // Enviar mensaje con imagen
      final auth = Provider.of<AuthService>(context, listen: false);
      final chat = Provider.of<ChatService>(context, listen: false);
      final text = _messageController.text.trim();
      final error = await chat.sendMessage(
        userId: auth.currentUser!.id,
        userName: auth.currentUser!.name,
        text: text.isEmpty ? null : text,
        groupId: widget.groupId,
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      if (error == null) {
        _messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _send() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final chat = Provider.of<ChatService>(context, listen: false);
    final text = _messageController.text.trim();
    if (text.isEmpty) return; // No enviar mensaje vacío
    
    final error = await chat.sendMessage(
      userId: auth.currentUser!.id,
      userName: auth.currentUser!.name,
      text: text,
      groupId: widget.groupId,
    );
    if (!mounted) return;
    if (error == null) {
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  String _dateHeaderLabel(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return 'Hoy';
    if (d == yesterday) return 'Ayer';
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatService>(context);
    final auth = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName ?? 'Chat Global'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder(
                stream: chat.messagesStream(groupId: widget.groupId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final messageId = data['id'] as String? ?? docs[index].id;
                      final isMine = data['userId'] == auth.currentUser?.id;
                      // Obtener fecha/hora
                      DateTime? createdAt;
                      final rawTs = data['createdAt'];
                      if (rawTs is Timestamp) {
                        createdAt = rawTs.toDate();
                      } else if (rawTs is String) {
                        createdAt = DateTime.tryParse(rawTs);
                      }
                      final timeLabel = createdAt != null
                          ? _formatTime(createdAt)
                          : null; // puede ser null mientras llega serverTimestamp
                      // Determinar si debemos mostrar separador de fecha
                      bool showHeader = false;
                      if (createdAt != null) {
                        DateTime? nextDate; // mensaje anterior en la UI
                        if (index + 1 < docs.length) {
                          final nextData = docs[index + 1].data() as Map<String, dynamic>;
                          final nextTs = nextData['createdAt'];
                          if (nextTs is Timestamp) nextDate = nextTs.toDate();
                          if (nextTs is String) nextDate = DateTime.tryParse(nextTs);
                        }
                        if (nextDate == null ||
                            DateTime(nextDate.year, nextDate.month, nextDate.day) !=
                                DateTime(createdAt.year, createdAt.month, createdAt.day)) {
                          showHeader = true;
                        }
                      }

                      final bubble = Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Reportar mensaje'),
                                content: const Text('¿Deseas reportar este mensaje?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reportar')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final err = await chat.reportMessage(
                                messageId: messageId,
                                groupId: widget.groupId,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err ?? 'Mensaje reportado')),
                              );
                            }
                          },
                          child: _ChatMessageBubble(
                            text: data['text'] ?? '',
                            userName: data['userName'] as String?,
                            isMine: isMine,
                            timeLabel: timeLabel,
                            imageUrl: data['imageUrl'] as String?, // RF-11: URL de imagen
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        ),
                      );

                      if (showHeader && createdAt != null) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Text(
                                    _dateHeaderLabel(createdAt),
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            bubble,
                          ],
                        );
                      }

                      return bubble;
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // RF-11: Botón para adjuntar imagen
                  IconButton(
                    icon: Icon(
                      _isUploadingImage ? Icons.hourglass_empty : Icons.add_photo_alternate,
                      color: _isUploadingImage 
                          ? colorScheme.onSurfaceVariant 
                          : colorScheme.primary,
                    ),
                    onPressed: _isUploadingImage ? null : _sendImage,
                    tooltip: 'Agregar imagen',
                  ),
                  const SizedBox(width: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: colorScheme.onPrimary),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
