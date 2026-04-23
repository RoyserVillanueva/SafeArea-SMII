import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

/// Servicio para manejar subida de imágenes a Firebase Storage
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Obtener una imagen desde la galería o cámara
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 85, // Calidad reducida para optimizar tamaño
        maxWidth: 1920, // Máximo ancho
        maxHeight: 1920, // Máximo alto
      );
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      return null;
    }
  }

  /// Subir una imagen desde XFile a Firebase Storage
  /// 
  /// [file] - Archivo XFile obtenido de image_picker
  /// [folder] - Carpeta donde se guardará (ej: 'reports', 'chat', 'profile')
  /// [fileName] - Nombre del archivo (opcional, se genera uno único si no se proporciona)
  /// 
  /// Retorna la URL de descarga de la imagen subida
  Future<String?> uploadImageFile({
    required XFile file,
    required String folder,
    String? fileName,
  }) async {
    try {
      // Verificar autenticación antes de intentar subir
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        debugPrint('StorageService: ERROR - Usuario no autenticado');
        throw Exception('Usuario no autenticado. Por favor inicia sesión antes de subir imágenes.');
      }

      debugPrint('StorageService: Usuario autenticado: ${currentUser.uid}');
      debugPrint('StorageService: Iniciando subida de imagen a Cloudinary');
      debugPrint('StorageService: Carpeta lógica en app (Firestore): $folder');
      debugPrint('StorageService: Archivo: ${file.name}');
      try {
        final fileSize = await file.length();
        debugPrint('StorageService: Tamaño: $fileSize bytes');
      } catch (e) {
        debugPrint('StorageService: No se pudo obtener tamaño del archivo: $e');
      }

      // Configuración de Cloudinary
      const String cloudName = 'djnjqzrvd';
      const String uploadPreset = 'safearea_preset';
      const String cloudinaryFolder = 'safearea';

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // Crear petición multipart
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = cloudinaryFolder;

      if (kIsWeb) {
        debugPrint('StorageService: Cloudinary - modo Web, leyendo bytes...');
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
          ),
        );
      } else {
        debugPrint('StorageService: Cloudinary - modo Mobile, usando File...');
        final fileIo = File(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            fileIo.path,
            filename: file.name,
          ),
        );
      }

      debugPrint('StorageService: Cloudinary - enviando solicitud...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('StorageService: Cloudinary - statusCode: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('StorageService: Cloudinary - cuerpo de respuesta: ${response.body}');
        throw Exception('Error al subir imagen a Cloudinary (status: ${response.statusCode})');
      }

      final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
      final downloadUrl = data['secure_url'] as String?;

      if (downloadUrl == null || downloadUrl.isEmpty) {
        debugPrint('StorageService: Cloudinary - secure_url vacío en respuesta: ${response.body}');
        throw Exception('No se pudo obtener la URL de la imagen subida en Cloudinary.');
      }

      debugPrint('StorageService: Cloudinary - URL obtenida: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('StorageService: Error al subir imagen: $e');
      debugPrint('StorageService: StackTrace: $stackTrace');
      debugPrint('StorageService: Tipo de error: ${e.runtimeType}');
      
      // Proporcionar mensajes de error más descriptivos
      String errorMessage = 'Error desconocido';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('permission-denied') || errorString.contains('403')) {
        errorMessage = 'Permiso denegado. Verifica las reglas de Firebase Storage y asegúrate de estar autenticado.';
      } else if (errorString.contains('unauthenticated') || errorString.contains('401')) {
        errorMessage = 'Usuario no autenticado. Por favor inicia sesión.';
      } else if (errorString.contains('quota') || errorString.contains('507')) {
        errorMessage = 'Cuota de almacenamiento excedida.';
      } else if (errorString.contains('cors') || errorString.contains('network')) {
        errorMessage = 'Error de red (CORS). Verifica:\n1. Que estés autenticado\n2. Las reglas de Firebase Storage\n3. Que Firebase Storage esté habilitado';
      } else if (errorString.contains('canceled') || errorString.contains('cancel')) {
        errorMessage = 'Subida cancelada.';
      } else {
        errorMessage = e.toString();
      }
      
      debugPrint('StorageService: Mensaje de error: $errorMessage');
      
      // Lanzar excepción con mensaje descriptivo para que la UI pueda manejarla
      throw Exception(errorMessage);
    }
  }
  
  /// Obtener el tipo MIME basado en la extensión del archivo
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Por defecto
    }
  }

  /// Subir múltiples imágenes
  /// Retorna lista de URLs de las imágenes subidas
  Future<List<String>> uploadImageFiles({
    required List<XFile> files,
    required String folder,
  }) async {
    final List<String> urls = [];
    
    for (final file in files) {
      final url = await uploadImageFile(
        file: file,
        folder: folder,
      );
      if (url != null) {
        urls.add(url);
      }
    }
    
    return urls;
  }

  /// Eliminar una imagen de Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extraer la ruta del archivo desde la URL
      final uri = Uri.parse(imageUrl);
      final path = uri.path.split('/o/').last.split('?').first;
      final decodedPath = Uri.decodeComponent(path);
      
      final ref = _storage.ref().child(decodedPath);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar imagen: $e');
      return false;
    }
  }
}

