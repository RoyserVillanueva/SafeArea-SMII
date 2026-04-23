import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'local_notification_listener.dart';
import 'chat_service.dart'; 

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser; 
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserModel? get currentUser => _currentUser; 
  bool get isLoading => _isLoading;
  /// Verificar si el usuario tiene teléfono validado
  bool get hasVerifiedPhone {
    final user = _auth.currentUser;
    return user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;
  }
  /// Obtener número de teléfono del usuario actual
  String? get userPhoneNumber {
    return _auth.currentUser?.phoneNumber;
  }

  AuthService() {
    _loadCurrentUser();
    // Escuchar cambios de autenticación de Firebase
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        _stopListeningToUser();
        _currentUser = null;
        notifyListeners();
      } else {
        _startListeningToUser(user.uid);
      }
    });
  }

  /// Cargar usuario desde SharedPreferences (para inicio rápido)
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId != null) {
      try {
        debugPrint('📥 Cargando usuario desde Firestore: $userId');
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          debugPrint('📄 Datos completos del documento: $data');
          debugPrint('🔑 Campo role en documento: ${data['role']} (tipo: ${data['role'].runtimeType})');
          
          _currentUser = UserModel.fromMap(data);
          debugPrint('✅ Usuario cargado. Rol: "${_currentUser!.role}", isAdmin: ${_currentUser!.isAdmin}');
          
          notifyListeners();
          // Iniciar listener para sincronización en tiempo real
          _startListeningToUser(userId);
        } else {
          debugPrint('⚠️ Documento de usuario no existe en Firestore');
        }
      } catch (e) {
        debugPrint('❌ Error cargando usuario: $e');
      }
    } else {
      debugPrint('ℹ️ No hay userId guardado en SharedPreferences');
    }
  }

  /// Iniciar listener para sincronización en tiempo real del usuario
  void _startListeningToUser(String userId) {
    _stopListeningToUser(); // Cancelar listener anterior si existe
    
    debugPrint('Iniciando listener para usuario: $userId');
    
    _userSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      (DocumentSnapshot doc) {
        if (doc.exists && doc.data() != null) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('Listener recibió datos: role=${data['role']}');
            
            final updatedUser = UserModel.fromMap(data);
            final oldRole = _currentUser?.role;
            final newRole = updatedUser.role;
            
            // Siempre actualizar el usuario y notificar si el rol cambió
            _currentUser = updatedUser;
            
            if (oldRole != newRole) {
              debugPrint('⚠️ ROL CAMBIÓ: $oldRole → $newRole');
              debugPrint('isAdmin: ${updatedUser.isAdmin}');
            } else {
              debugPrint('Usuario sincronizado. Rol actual: $newRole, isAdmin: ${updatedUser.isAdmin}');
            }
            
            notifyListeners();
          } catch (e) {
            debugPrint('❌ Error parseando usuario desde Firebase: $e');
            debugPrint('Datos recibidos: ${doc.data()}');
          }
        } else {
          debugPrint('⚠️ Documento de usuario no existe en Firestore');
        }
      },
      onError: (error) {
        debugPrint('❌ Error en listener de usuario: $error');
      },
    );
  }

  /// Detener listener del usuario
  void _stopListeningToUser() {
    _userSubscription?.cancel();
    _userSubscription = null;
  }

  /// Recargar usuario desde Firebase (útil después de cambios)
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    
    try {
      debugPrint('Refrescando usuario: ${_currentUser!.id}');
      final userDoc = await _firestore.collection('users').doc(_currentUser!.id).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        debugPrint('Datos desde Firestore: role=${data['role']}');
        final oldRole = _currentUser!.role;
        _currentUser = UserModel.fromMap(data);
        debugPrint('Usuario refrescado. Rol: ${_currentUser!.role}, isAdmin: ${_currentUser!.isAdmin}');
        
        if (oldRole != _currentUser!.role) {
          debugPrint('🔄 ROL CAMBIÓ después del refresh: $oldRole → ${_currentUser!.role}');
        }
        
        notifyListeners();
      } else {
        debugPrint('⚠️ Documento no existe al refrescar');
      }
    } catch (e) {
      debugPrint('❌ Error refrescando usuario: $e');
    }
  }

  @override
  void dispose() {
    _stopListeningToUser();
    super.dispose();
  }

  Future<String?> register(String email, String password, String name, String? phone) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // 🔐 NUEVO: Enviar correo de verificación
      await userCredential.user!.sendEmailVerification();

      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        phone: phone,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.id).set({
        ...user.toMap(),
        'isOnline': true,
        'lastSeen': DateTime.now().toIso8601String(),
        'emailVerified': false, // 🔐 NUEVO: Campo para tracking
      });

      _currentUser = user;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.id);

      // Iniciar listener para sincronización en tiempo real del rol
      _startListeningToUser(user.id);

      // NO iniciar sesión automáticamente - el usuario debe verificar email primero
      _isLoading = false;
      notifyListeners();

      // Inicializar servicios en segundo plano (no bloquean el registro)
      _initializeServicesInBackground(user.id);

      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Error inesperado: $e';
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user!;
      // 🔐 NUEVO: Verificar que el email esté validado
      if (!user.emailVerified) {
        await _auth.signOut();
        _isLoading = false;
        notifyListeners();
        return 'email_not_verified'; // Código especial para manejar en UI
      }

      final uid = user.uid;
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        // Crear el documento del usuario si no existe
        final newUser = UserModel(
          id: uid,
          email: userCredential.user!.email ?? email,
          name: userCredential.user!.displayName ?? email.split('@').first,
          phone: userCredential.user!.phoneNumber,
          createdAt: DateTime.now(),
        );
        await userDocRef.set({
          ...newUser.toMap(),
          'isOnline': true,
          'lastSeen': DateTime.now().toIso8601String(),
          'emailVerified': true,
        });
        _currentUser = newUser;
      } else {
        final userData = userDoc.data()!;

        debugPrint('Login - Datos del usuario desde Firestore: role=${userData['role']}');
        _currentUser = UserModel.fromMap(userData);
        debugPrint('Login - Usuario cargado. Rol: ${_currentUser!.role}, isAdmin: ${_currentUser!.isAdmin}');
      }

      // Marcar presencia en línea
      // 🔐 NUEVO: Actualizar estado de verificación en Firestore
      await userDocRef.update({
        'emailVerified': true,
        'isOnline': true,
        'lastSeen': DateTime.now().toIso8601String(),
      });

      // Persistir usuario
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', _currentUser!.id);

      // Iniciar listener para sincronización en tiempo real del rol
      _startListeningToUser(_currentUser!.id);
      
      // Forzar una actualización inmediata después de iniciar el listener
      await Future.delayed(const Duration(milliseconds: 500));
      await refreshCurrentUser();
      debugPrint('Login - Usuario refrescado. Rol final: ${_currentUser?.role}, isAdmin: ${_currentUser?.isAdmin}');

      // Finalizar login inmediatamente (no esperar inicializaciones pesadas)
      _isLoading = false;
      notifyListeners();

      // Inicializar servicios en segundo plano (no bloquean el login)
      _initializeServicesInBackground(_currentUser!.id);

      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Error inesperado: $e';
    }
  }

  /// Inicializar servicios en segundo plano para no bloquear el login
  void _initializeServicesInBackground(String userId) {
    // Ejecutar en segundo plano sin bloquear
    Future.microtask(() async {
      try {
        // Inicializar notificaciones
        await NotificationService().initialize(userId);
        // Inicializar listener de notificaciones locales
        await LocalNotificationListener.instance.initialize(userId);
      } catch (e) {
        debugPrint('Error inicializando notificaciones: $e');
      }
      
      // Inicializar zonas predefinidas de chat
      try {
        final chatService = ChatService();
        await chatService.initializePredefinedZones();
      } catch (e) {
        debugPrint('Error inicializando zonas predefinidas: $e');
      }
    });
  }

  Future<void> logout() async {
    try {
      final userId = _currentUser?.id;

      // Marcar usuario como desconectado en Firestore
      if (userId != null) {
        try {
          await _firestore.collection('users').doc(userId).update({
            'isOnline': false,
            'lastSeen': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Error actualizando presencia al cerrar sesión: $e');
        }
      }

      await _auth.signOut();
      
      // Limpiar token de notificaciones
      if (userId != null) {
        try {
          await NotificationService().unsubscribe(userId);
        } catch (e) {
          debugPrint('Error limpiando notificaciones: $e');
        }
      }
      
      _currentUser = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  Future<String?> updateProfile(String name, String? phone, {String? profileImage}) async {
    try {
      if (_currentUser == null) return 'No hay usuario logueado';

      final updatedUser = UserModel( 
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: name,
        phone: phone,
        profileImage: profileImage,
        createdAt: _currentUser!.createdAt,
        role: _currentUser!.role, // RF-16: Mantener role
        isActive: _currentUser!.isActive, // RF-16: Mantener estado activo
      );

      await _firestore.collection('users').doc(_currentUser!.id).update({
        'name': name,
        'phone': phone,
        'profileImage': profileImage,
      });

      _currentUser = updatedUser;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Error al actualizar perfil: $e';
    }
  }

  // Método para obtener usuario por ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data()!); 
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  // Método para actualizar último login
  Future<void> updateLastLogin() async {
    if (_currentUser != null) {
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'lastLogin': DateTime.now(),
      });
    }
  }

  /// Cambiar el rol de un usuario (solo administradores)
  Future<String?> changeUserRole(String userId, String newRole) async {
    try {
      if (_currentUser == null || !_currentUser!.isAdmin) {
        return 'No tienes permisos para cambiar roles';
      }

      if (userId == _currentUser!.id) {
        return 'No puedes cambiar tu propio rol';
      }

      // Validar que el rol sea válido
      if (newRole != 'user' && newRole != 'admin') {
        return 'Rol inválido. Debe ser "user" o "admin"';
      }

      // Actualizar rol en Firestore
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
      });

      // El listener en tiempo real actualizará automáticamente el estado
      // Pero forzamos una actualización inmediata si es el usuario actual
      if (userId == _currentUser!.id) {
        await refreshCurrentUser();
      }

      debugPrint('Rol cambiado en Firebase: $userId -> $newRole');
      return null;
    } catch (e) {
      return 'Error al cambiar rol: $e';
    }
  }
  /// Reenviar correo de verificación al usuario actual
  Future<String?> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'No hay usuario activo';
      }
      
      if (user.emailVerified) {
        return 'Tu email ya está verificado';
      }
      
      await user.sendEmailVerification();
      return null; // Éxito
    } catch (e) {
      return 'Error al reenviar verificación: $e';
    }
  }

  /// Verificar si el email del usuario actual está verificado
  bool isEmailVerified() {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }
}