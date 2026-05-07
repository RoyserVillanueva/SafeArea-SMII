# SafeArea - Aplicación de Seguridad Comunitaria

Aplicación móvil desarrollada en Flutter para reportar y gestionar incidentes de seguridad en la comunidad. Los usuarios pueden crear reportes, comunicarse mediante chat grupal y recibir notificaciones en tiempo real.

## 📋 Características Principales

### ✅ Implementado

- **Autenticación de Usuarios**
  - Registro con email y contraseña
  - Inicio de sesión
  - Perfil de usuario editable
  - Cierre de sesión

- **Gestión de Reportes**
  - Crear reportes de incidentes (Robo, Incendio, Emergencia, Accidente, Otro)
  - Editar reportes (dentro de 24 horas de creación)
  - Cambiar estado de reportes (Activo, En Proceso, Resuelto)
  - Eliminar reportes (solo creador)
  - Filtros por tipo y estado
  - **Subida de imágenes** (hasta 5 por reporte) 📷
  - Visualización de imágenes en detalle
  - Protección de ubicación (solo dueño ve ubicación completa)

- **Chat Comunitario**
  - Chat grupal por zonas predefinidas
  - Crear grupos personalizados
  - Enviar mensajes de texto
  - Reportar mensajes inapropiados
  - **Soporte para imágenes en mensajes** 📷

- **Notificaciones**
  - Notificaciones push para nuevos reportes
  - Notificaciones de cambios de estado
  - Notificaciones de nuevos mensajes en chat
  - Notificaciones locales en primer plano
  - Notificaciones del sistema en segundo plano/cerrada
  - Soporte para imágenes en notificaciones

- **Roles de Usuario**
  - Sistema de roles (Usuario, Administrador)
  - Verificación de permisos para moderación
  - Campo `role` en modelo de usuario

- **Plataformas**
  - ✅ Android (completo)
  - ✅ Web (completo, para desarrollo y pruebas)

## 🚀 Tecnologías Utilizadas

- **Flutter** ^3.7.2
- **Firebase**
  - Firebase Auth (autenticación)
  - Cloud Firestore (base de datos)
  - Firebase Storage (almacenamiento de imágenes)
  - Firebase Messaging (notificaciones push)
- **Provider** (gestión de estado)
- **Flutter Map** (mapas con OpenStreetMap)
- **Image Picker** (selección de imágenes)

## 📦 Instalación

### Requisitos Previos

- Flutter SDK ^3.7.2
- Dart SDK
- Firebase CLI (opcional, para Cloud Functions)
- Cuenta de Firebase

### Pasos de Instalación

1. **Clonar el repositorio**
   ```bash
   git clone [url-del-repositorio]
   cd proyecto_safearea
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase**
   - Crea un proyecto en [Firebase Console](https://console.firebase.google.com)
   - Descarga `google-services.json` y colócalo en `android/app/`
   - Configura Firebase para Web en `web/`
   - Ejecuta `flutterfire configure` para generar `firebase_options.dart`

4. **Configurar Firebase Storage**
   - Ve a Firebase Console → Storage
   - Crea un bucket (si no existe)
   - Configura las reglas de seguridad:
     ```javascript
     rules_version = '2';
     service firebase.storage {
       match /b/{bucket}/o {
         match /{allPaths=**} {
           allow read: if true;
           allow write: if request.auth != null
             && request.resource.size < 5 * 1024 * 1024  // Máximo 5MB
             && request.resource.contentType.matches('image/.*');
           allow delete: if request.auth != null;
         }
       }
     }
     ```
   - **⚠️ IMPORTANTE para Web**: Configura CORS para localhost (ver `docs/SOLUCIONAR_CORS_STORAGE.md`)

5. **Ejecutar la aplicación**
   ```bash
   # Android
   flutter run

   # Web
   flutter run -d chrome
   ```

## 🔧 Configuración

### Firebase Storage

Firebase Storage funciona con el plan **Spark (gratuito)**. Las imágenes se almacenan en:
- `reports/` - Imágenes de reportes
- `chat/` - Imágenes de mensajes del chat
- `profile/` - Fotos de perfil (futuro)

### Notificaciones Push

Las notificaciones automáticas requieren **Cloud Functions**, que necesita el plan **Blaze** de Firebase.

**Estado actual**: Cloud Functions **no está desplegada** porque requiere plan de pago.

**Funciona**:
- ✅ Notificaciones manuales desde Firebase Console
- ✅ Notificaciones locales (primer plano)
- ✅ Token FCM se guarda correctamente

**No funciona** (requiere Blaze Plan):
- ❌ Notificaciones automáticas del chat
- ❌ Notificaciones automáticas de nuevos reportes
- ❌ Notificaciones automáticas de cambios de estado

Ver `docs/DESPLIEGUE_CLOUD_FUNCTIONS.md` para instrucciones de despliegue cuando tengas el plan Blaze.

## 📱 Uso de la Aplicación

### Crear un Reporte

1. Inicia sesión en la app
2. Ve a "Reportes" → "Nuevo Reporte"
3. Selecciona el tipo de incidente
4. Completa título, descripción y ubicación
5. (Opcional) Agrega hasta 5 imágenes
6. Selecciona ubicación en el mapa o busca una dirección
7. Presiona "Crear Reporte"

### Enviar Mensajes con Imágenes en Chat

1. Ve a "Chat" → Selecciona un grupo
2. Toca el botón de adjuntar imagen (📷)
3. Elige "Tomar foto" o "Galería"
4. La imagen se subirá automáticamente
5. Opcionalmente agrega texto
6. Envía el mensaje

### Administrar Reportes

**Como Creador**:
- Puedes editar tu reporte dentro de las primeras 24 horas
- Puedes cambiar el estado (Activo, En Proceso, Resuelto)
- Puedes eliminar tu reporte

**Como Administrador** (futuro):
- Podrás moderar todos los reportes
- Podrás eliminar cualquier reporte

## 🗂️ Estructura del Proyecto

```
proyecto_safearea/
├── lib/
│   ├── main.dart              # Punto de entrada
│   ├── models/                # Modelos de datos
│   │   ├── user_model.dart
│   │   ├── report_model.dart
│   │   └── chat_group_model.dart
│   ├── screens/               # Pantallas
│   │   ├── login_screen.dart
│   │   ├── home_screen.dart
│   │   ├── add_report_screen.dart
│   │   ├── report_detail_screen.dart
│   │   ├── chat_screen.dart
│   │   └── ...
│   ├── services/              # Servicios
│   │   ├── auth_service.dart
│   │   ├── report_service.dart
│   │   ├── chat_service.dart
│   │   ├── notification_service.dart
│   │   └── storage_service.dart  # Nuevo: gestión de imágenes
│   ├── widgets/               # Widgets reutilizables
│   └── theme/                 # Tema de la aplicación
├── functions/                 # Cloud Functions (requiere Blaze Plan)
│   └── index.js
├── docs/                      # Documentación
└── android/                   # Configuración Android
```

## 🧪 Testing

Ejecuta los tests con:
```bash
flutter test
```

## 📝 Casos de Uso Implementados

Ver `docs/casos_de_uso.md` para la documentación completa de casos de uso.

### RF Implementados
- ✅ RF-01: Registro de usuario
- ✅ RF-02: Inicio de sesión
- ✅ RF-03: Perfil de usuario
- ✅ RF-04: Cierre de sesión
- ✅ RF-05: Crear reporte
- ✅ RF-06: Categorización
- ✅ RF-07: Gestión de estados
- ✅ RF-08: Edición de reportes
- ✅ RF-09: Listado de reportes
- ✅ RF-10: Chat grupal
- ✅ **RF-11: Envío de imágenes** 📷
- ✅ RF-17: Moderación de reportes

## 🚧 Funcionalidades Pendientes

### Requieren Plan Blaze de Firebase
- ⚠️ Cloud Functions desplegadas (notificaciones automáticas)

### Mejoras Futuras
- Geolocalización automática
- Compartir reportes
- Búsqueda de reportes
- Estadísticas/dashboard
- Historial de reportes por usuario
- Mejores permisos de administrador

## 📄 Licencia

Este proyecto es privado. Todos los derechos reservados.

## 👥 Contacto

Para preguntas o soporte, contacta al equipo de desarrollo.

---

**Nota**: Esta aplicación requiere Firebase para funcionar. Asegúrate de tener configurado Firebase correctamente antes de ejecutarla.
