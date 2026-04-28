// Proyecto SafeArea 
// Importaciones necesarias para la aplicación, incluyendo Firebase, Provider y servicios personalizados.
// Se establece la configuración de Firebase y se registra un handler para notificaciones en segundo plano.
// El widget principal de la aplicación utiliza MultiProvider para gestionar el estado de temas, idioma, autenticación, reportes y chat.
// Como pantalla de inicio se muestra el LoginScreen, y se configuran las localizaciones para español e inglés.
// Por el momento se omiten los detalles de implementación de los servicios y pantallas, enfocándonos en la estructura general de la aplicación.
// Solo la funcionalidad del LoginScreen y RegisterScreense muestra como pantalla de inicio, pero se espera que otras pantallas como ReportScreen, ChatScreen, etc. 
// Las pantallas siguientes solo mostraran funcionalidad simple. 
// Se completo el login con email y contrasenna (User Story 2).
// Se validaron satisfactoriamente los flujos de Registro (User Story 1)

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/report_service.dart';
import 'services/chat_service.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';

import 'services/notification_service.dart';
import 'services/notification_handler.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Registrar handler para notificaciones en segundo plano
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Crear GlobalKey para navegación desde notificaciones
  final navigatorKey = GlobalKey<NavigatorState>();
  NotificationService.navigatorKey = navigatorKey;
  
  runApp(MyApp(navigatorKey: navigatorKey));
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LanguageService()..loadLocale()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ReportService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
      ],
      child: Consumer2<ThemeService, LanguageService>(
        builder: (context, themeService, languageService, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SafeArea',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode, // Usar el modo del servicio
            locale: languageService.locale,
            supportedLocales: const [
              Locale('es'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const LoginScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}