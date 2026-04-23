# MODELO LÓGICO - SafeArea

## 3. MODELO LÓGICO

### a) Análisis de Objetos

El análisis de objetos identifica las entidades principales del sistema SafeArea y sus características:

#### **Objeto: User (Usuario)**
- **Propósito**: Representa a los usuarios del sistema
- **Atributos**:
  - `id`: Identificador único del usuario
  - `email`: Correo electrónico (usado para autenticación)
  - `name`: Nombre completo del usuario
  - `phone`: Número de teléfono (opcional)
  - `profileImage`: URL de la imagen de perfil (opcional)
  - `createdAt`: Fecha de creación de la cuenta
  - `role`: Rol del usuario ('user' o 'admin')
  - `isActive`: Estado activo/inactivo del usuario
- **Métodos principales**:
  - `isAdmin`: Verifica si el usuario es administrador
  - `canModerate()`: Verifica permisos de moderación
  - `copyWith()`: Crea una copia con valores modificados
  - `toMap()`: Serializa el objeto a formato Map para Firebase
  - `fromMap()`: Crea un objeto desde un Map de Firebase

#### **Objeto: Report (Reporte)**
- **Propósito**: Representa los reportes de incidentes de seguridad
- **Atributos**:
  - `id`: Identificador único del reporte
  - `userId`: ID del usuario que creó el reporte
  - `type`: Tipo de incidente (Robo, Incendio, Emergencia, Accidente, Otro)
  - `title`: Título del reporte
  - `description`: Descripción detallada del incidente
  - `location`: Dirección o ubicación textual
  - `latitude`: Coordenada de latitud (opcional)
  - `longitude`: Coordenada de longitud (opcional)
  - `status`: Estado del reporte (activo, en_proceso, resuelto)
  - `images`: Lista de URLs de imágenes asociadas (hasta 5)
  - `createdAt`: Fecha de creación
  - `updatedAt`: Fecha de última actualización
  - `verifiedBy`: Lista de IDs de usuarios que verificaron el reporte
  - `isActive`: Estado activo/inactivo del reporte
- **Métodos principales**:
  - `copyWith()`: Crea una copia modificada del reporte
  - `toMap()`: Serialización para Firebase
  - `fromMap()`: Deserialización desde Firebase

#### **Objeto: ChatGroup (Grupo de Chat)**
- **Propósito**: Representa grupos de chat comunitario
- **Atributos**:
  - `id`: Identificador único del grupo
  - `name`: Nombre del grupo
  - `description`: Descripción del grupo
  - `createdBy`: ID del usuario creador
  - `createdByName`: Nombre del usuario creador
  - `createdAt`: Fecha de creación
  - `members`: Lista de IDs de usuarios miembros
  - `isPublic`: Indica si el grupo es público o privado
  - `imageUrl`: URL de la imagen del grupo (opcional)
- **Métodos principales**:
  - `copyWith()`: Crea una copia modificada
  - `toMap()`: Serialización para Firebase
  - `fromMap()`: Deserialización desde Firebase

#### **Objeto: Message (Mensaje de Chat)**
- **Propósito**: Representa mensajes dentro de un grupo de chat
- **Atributos** (implícitos en la implementación):
  - `id`: Identificador único del mensaje
  - `userId`: ID del usuario que envió el mensaje
  - `userName`: Nombre del usuario
  - `text`: Contenido del mensaje
  - `imageUrl`: URL de imagen adjunta (opcional)
  - `createdAt`: Fecha y hora del mensaje
  - `groupId`: ID del grupo al que pertenece

#### **Objeto: AuthService (Servicio de Autenticación)**
- **Propósito**: Gestiona la autenticación y sesión de usuarios
- **Atributos principales**:
  - `_currentUser`: Usuario actual autenticado
  - `_isLoading`: Estado de carga
- **Métodos principales**:
  - `register()`: Registra un nuevo usuario
  - `login()`: Inicia sesión
  - `logout()`: Cierra sesión
  - `updateProfile()`: Actualiza el perfil del usuario
  - `_loadCurrentUser()`: Carga el usuario desde almacenamiento local

#### **Objeto: ReportService (Servicio de Reportes)**
- **Propósito**: Gestiona las operaciones CRUD de reportes
- **Atributos principales**:
  - `_isLoading`: Estado de carga
  - `_selectedFilter`: Filtro de tipo seleccionado
  - `_selectedStatus`: Filtro de estado seleccionado
- **Métodos principales**:
  - `createReport()`: Crea un nuevo reporte
  - `updateReport()`: Actualiza un reporte existente
  - `deleteReport()`: Elimina un reporte
  - `changeReportStatus()`: Cambia el estado de un reporte
  - `getReports()`: Obtiene lista de reportes

#### **Objeto: ChatService (Servicio de Chat)**
- **Propósito**: Gestiona los grupos de chat y mensajes
- **Atributos principales**:
  - `_currentGroupId`: ID del grupo actual
- **Métodos principales**:
  - `sendMessage()`: Envía un mensaje al grupo
  - `messagesStream()`: Stream de mensajes en tiempo real
  - `createGroup()`: Crea un nuevo grupo
  - `initializePredefinedZones()`: Inicializa zonas predefinidas

#### **Objeto: NotificationService (Servicio de Notificaciones)**
- **Propósito**: Gestiona las notificaciones push y locales
- **Métodos principales**:
  - `sendNewReportNotification()`: Notifica nuevo reporte
  - `sendChatNotification()`: Notifica nuevo mensaje
  - `initialize()`: Inicializa el servicio de notificaciones

#### **Objeto: StorageService (Servicio de Almacenamiento)**
- **Propósito**: Gestiona la subida de archivos (imágenes) a Firebase Storage
- **Métodos principales**:
  - `uploadImage()`: Sube una imagen
  - `uploadMultipleImages()`: Sube múltiples imágenes
  - `deleteImage()`: Elimina una imagen

---

### b) Diagrama de Actividades con Objetos

El diagrama de actividades muestra el flujo de procesos principales del sistema:

#### **Proceso: Crear Reporte**

```
[Inicio] → [Usuario selecciona "Nuevo Reporte"]
    ↓
[Usuario completa formulario]
    ↓
[Usuario selecciona imágenes (opcional)]
    ↓
[Usuario selecciona ubicación en mapa]
    ↓
[Presiona "Crear Reporte"]
    ↓
[ReportService.createReport()]
    ↓
[StorageService.uploadMultipleImages()] → [Firebase Storage]
    ↓
[ReportService crea documento] → [Firebase Firestore]
    ↓
[NotificationService.sendNewReportNotification()]
    ↓
[Notificación enviada a todos los usuarios]
    ↓
[Reporte visible en lista]
    ↓
[Fin]
```

**Objetos involucrados:**
- `User`: Usuario autenticado
- `Report`: Nuevo objeto reporte
- `ReportService`: Servicio que orquesta la creación
- `StorageService`: Gestiona imágenes
- `NotificationService`: Envía notificaciones
- `Firebase Firestore`: Base de datos
- `Firebase Storage`: Almacenamiento de imágenes

#### **Proceso: Enviar Mensaje en Chat**

```
[Inicio] → [Usuario selecciona grupo de chat]
    ↓
[Usuario escribe mensaje o adjunta imagen]
    ↓
[Si hay imagen: StorageService.uploadImage()]
    ↓
[ChatService.sendMessage()]
    ↓
[Mensaje guardado] → [Firebase Firestore]
    ↓
[NotificationService.sendChatNotification()]
    ↓
[Mensaje visible en tiempo real para todos los miembros]
    ↓
[Fin]
```

**Objetos involucrados:**
- `User`: Usuario que envía
- `ChatGroup`: Grupo destino
- `Message`: Nuevo mensaje
- `ChatService`: Gestiona el envío
- `StorageService`: Sube imagen (si aplica)
- `NotificationService`: Notifica a otros miembros

#### **Proceso: Autenticación de Usuario**

```
[Inicio] → [Usuario ingresa email y contraseña]
    ↓
[Presiona "Iniciar Sesión"]
    ↓
[AuthService.login()]
    ↓
[Firebase Auth verifica credenciales]
    ↓
[Si válido: AuthService obtiene datos de usuario]
    ↓
[AuthService._loadCurrentUser()]
    ↓
[Datos cargados desde Firestore]
    ↓
[UserModel creado]
    ↓
[Sesión iniciada]
    ↓
[Navegación a HomeScreen]
    ↓
[Fin]
```

**Objetos involucrados:**
- `User`: Credenciales ingresadas
- `AuthService`: Gestiona autenticación
- `UserModel`: Usuario autenticado
- `Firebase Auth`: Autenticación
- `Firebase Firestore`: Datos de usuario

---

### c) Diagrama de Secuencia

Muestra la interacción entre objetos en escenarios específicos:

#### **Secuencia: Crear Reporte con Imágenes**

```
Usuario          UI Screen        ReportService    StorageService    Firebase Firestore    Firebase Storage    NotificationService
  |                  |                  |                 |                  |                      |                      |
  |--[Completa form]-->                  |                 |                  |                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |--[Presiona Crear]--->                |                 |                  |                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |--[createReport()]-->                |                  |                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |--[uploadMultipleImages()]-->       |                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |                 |--[Upload]-------->|                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |                 |<--[URLs]----------|                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |--[set() con datos]--->             |                      |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |                 |                  |<--[Documento creado]--|                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |--[sendNewReportNotification()]--->                     |                      |
  |                  |                  |                 |                  |                      |                      |
  |                  |                  |                 |                  |                      |<--[Notificación enviada]
  |                  |                  |                 |                  |                      |                      |
  |<--[Éxito]--------|<--[Éxito]--------|<--[Reporte creado]                 |                      |                      |
  |                  |                  |                 |                  |                      |                      |
```

#### **Secuencia: Autenticación de Usuario**

```
Usuario          LoginScreen      AuthService      Firebase Auth      Firebase Firestore
  |                  |                  |                 |                      |
  |--[Email/Password]--->              |                 |                      |
  |                  |                  |                 |                      |
  |--[Presiona Login]--->              |                 |                      |
  |                  |                  |                 |                      |
  |                  |--[login()]------->                 |                      |
  |                  |                  |                 |                      |
  |                  |                  |--[signInWithEmailAndPassword()]------>|
  |                  |                  |                 |                      |
  |                  |                  |<--[User Auth]---|                      |
  |                  |                  |                 |                      |
  |                  |                  |--[get() user doc]--->                |
  |                  |                  |                 |                      |
  |                  |                  |                 |<--[User data]--------|
  |                  |                  |                 |                      |
  |                  |                  |--[UserModel.fromMap()]                |
  |                  |                  |                 |                      |
  |                  |<--[currentUser]--|                 |                      |
  |                  |                  |                 |                      |
  |<--[Navegar a Home]--                 |                 |                      |
  |                  |                  |                 |                      |
```

#### **Secuencia: Enviar Mensaje en Chat**

```
Usuario          ChatScreen       ChatService      StorageService    Firebase Firestore    NotificationService
  |                  |                  |                 |                      |                      |
  |--[Escribe mensaje]--->              |                 |                      |                      |
  |                  |                  |                 |                      |                      |
  |--[Adjunta imagen]--->               |                 |                      |                      |
  |                  |                  |                 |                      |                      |
  |--[Presiona Enviar]--->              |                 |                      |                      |
  |                  |                  |                 |                      |                      |
  |                  |--[sendMessage()]-->                |                      |                      |
  |                  |                  |                 |                      |                      |
  |                  |                  |--[uploadImage()]--->                   |                      |
  |                  |                  |                 |                      |                      |
  |                  |                  |                 |--[Upload]-------->   |                      |
  |                  |                  |                 |                      |                      |
  |                  |                  |                 |<--[URL]-------------|                      |
  |                  |                  |                 |                      |                      |
  |                  |                  |--[add() message]--->                   |                      |
  |                  |                  |                 |                      |                      |
  |                  |                  |                 |<--[Message saved]---|                      |
  |                  |                  |                 |                      |                      |
  |                  |                  |--[sendChatNotification()]------------->|
  |                  |                  |                 |                      |                      |
  |                  |<--[Mensaje visible]                |                      |                      |
  |                  |                  |                 |                      |                      |
  |<--[Mensaje en chat]                 |                 |                      |                      |
  |                  |                  |                 |                      |                      |
```

---

### d) Diagrama de Clases

Representa la estructura estática del sistema con sus relaciones:

```
┌─────────────────────────────────────────────────────────────────┐
│                         SafeArea Application                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                           MyApp                                  │
│  ─────────────────────────────────────────────────────────────  │
│  + navigatorKey: GlobalKey<NavigatorState>                       │
│  ─────────────────────────────────────────────────────────────  │
│  + build(): Widget                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ provides
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Provider Services                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ AuthService  │  │ ReportService│  │ ChatService  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │ ThemeService │  │ Notification │                            │
│  └──────────────┘  │   Service    │                            │
│                    └──────────────┘                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                           UserModel                              │
│  ─────────────────────────────────────────────────────────────  │
│  - id: String                                                    │
│  - email: String                                                 │
│  - name: String                                                  │
│  - phone: String?                                                │
│  - profileImage: String?                                         │
│  - createdAt: DateTime                                           │
│  - role: String                                                  │
│  - isActive: bool                                                │
│  ─────────────────────────────────────────────────────────────  │
│  + isAdmin: bool                                                 │
│  + canModerate(): bool                                           │
│  + copyWith(...): UserModel                                      │
│  + toMap(): Map<String, dynamic>                                 │
│  + fromMap(Map): UserModel                                       │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
                    ┌─────────┴─────────┐
                    │                   │
              ┌──────────┐      ┌──────────────┐
              │ AuthService│      │  Report      │
              └──────────┘      └──────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                             Report                               │
│  ─────────────────────────────────────────────────────────────  │
│  - id: String                                                    │
│  - userId: String                                                │
│  - type: String                                                  │
│  - title: String                                                 │
│  - description: String                                           │
│  - location: String                                              │
│  - latitude: double?                                             │
│  - longitude: double?                                            │
│  - status: String                                                │
│  - images: List<String>                                          │
│  - createdAt: DateTime                                           │
│  - updatedAt: DateTime                                           │
│  - verifiedBy: List<String>                                      │
│  - isActive: bool                                                │
│  ─────────────────────────────────────────────────────────────  │
│  + copyWith(...): Report                                         │
│  + toMap(): Map<String, dynamic>                                 │
│  + fromMap(Map): Report                                          │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
                        ┌─────┴─────┐
                        │           │
                  ┌──────────┐ ┌──────────┐
                  │ Report    │ │ Storage  │
                  │ Service   │ │ Service  │
                  └──────────┘ └──────────┘

┌─────────────────────────────────────────────────────────────────┐
│                           ChatGroup                              │
│  ─────────────────────────────────────────────────────────────  │
│  - id: String                                                    │
│  - name: String                                                  │
│  - description: String                                           │
│  - createdBy: String                                             │
│  - createdByName: String                                         │
│  - createdAt: DateTime                                           │
│  - members: List<String>                                         │
│  - isPublic: bool                                                │
│  - imageUrl: String?                                             │
│  ─────────────────────────────────────────────────────────────  │
│  + copyWith(...): ChatGroup                                      │
│  + toMap(): Map<String, dynamic>                                 │
│  + fromMap(Map): ChatGroup                                       │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
                        ┌─────┴─────┐
                        │           │
                  ┌──────────┐ ┌──────────┐
                  │ Chat      │ │ Storage  │
                  │ Service   │ │ Service  │
                  └──────────┘ └──────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         AuthService                              │
│  ─────────────────────────────────────────────────────────────  │
│  - _auth: FirebaseAuth                                           │
│  - _firestore: FirebaseFirestore                                 │
│  - _currentUser: UserModel?                                      │
│  - _isLoading: bool                                              │
│  ─────────────────────────────────────────────────────────────  │
│  + currentUser: UserModel?                                       │
│  + isLoading: bool                                               │
│  + register(...): Future<String?>                                │
│  + login(...): Future<String?>                                    │
│  + logout(): Future<void>                                        │
│  + updateProfile(...): Future<String?>                            │
│  - _loadCurrentUser(): Future<void>                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                              ▼
                        ┌──────────────┐
                        │   Firebase   │
                        │     Auth     │
                        └──────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ReportService                             │
│  ─────────────────────────────────────────────────────────────  │
│  - _firestore: FirebaseFirestore                                 │
│  - _isLoading: bool                                              │
│  - _selectedFilter: String                                       │
│  - _selectedStatus: String                                       │
│  ─────────────────────────────────────────────────────────────  │
│  + isLoading: bool                                               │
│  + selectedFilter: String                                        │
│  + selectedStatus: String                                        │
│  + createReport(...): Future<String?>                             │
│  + updateReport(...): Future<String?>                             │
│  + deleteReport(...): Future<String?>                             │
│  + changeReportStatus(...): Future<String?>                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                    ┌─────────┴─────────┐
                    │                   │
              ┌──────────┐      ┌──────────────┐
              │ Firestore│      │ Notification │
              │          │      │   Service    │
              └──────────┘      └──────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         ChatService                              │
│  ─────────────────────────────────────────────────────────────  │
│  - _firestore: FirebaseFirestore                                 │
│  - _currentGroupId: String?                                      │
│  ─────────────────────────────────────────────────────────────  │
│  + messagesStream(...): Stream<QuerySnapshot>                     │
│  + setCurrentGroup(String?): void                                 │
│  + sendMessage(...): Future<String?>                              │
│  + createGroup(...): Future<String?>                              │
│  + initializePredefinedZones(): Future<void>                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                    ┌─────────┴─────────┐
                    │                   │
              ┌──────────┐      ┌──────────────┐
              │ Firestore│      │ Notification │
              │          │      │   Service    │
              └──────────┘      └──────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        StorageService                            │
│  ─────────────────────────────────────────────────────────────  │
│  - _storage: FirebaseStorage                                     │
│  ─────────────────────────────────────────────────────────────  │
│  + uploadImage(...): Future<String?>                              │
│  + uploadMultipleImages(...): Future<List<String>>                │
│  + deleteImage(...): Future<void>                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                              ▼
                        ┌──────────────┐
                        │   Firebase   │
                        │   Storage    │
                        └──────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      NotificationService                         │
│  ─────────────────────────────────────────────────────────────  │
│  - _messaging: FirebaseMessaging                                 │
│  - _localNotifications: FlutterLocalNotificationsPlugin          │
│  ─────────────────────────────────────────────────────────────  │
│  + navigatorKey: GlobalKey<NavigatorState>?                      │
│  + initialize(): Future<void>                                    │
│  + sendNewReportNotification(...): Future<void>                   │
│  + sendChatNotification(...): Future<void>                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                    ┌─────────┴─────────┐
                    │                   │
              ┌──────────┐      ┌──────────────┐
              │ Firebase  │      │   Local      │
              │ Messaging │      │ Notifications│
              └──────────┘      └──────────────┘

```

**Leyenda de Relaciones:**
- `uses`: Dependencia de uso
- `provides`: Provee servicio
- `inherits`: Herencia (no aplica en este caso)
- `contains`: Contiene/composición

---

## CONCLUSIONES

1. **Arquitectura Modular**: El sistema SafeArea utiliza una arquitectura modular basada en servicios (AuthService, ReportService, ChatService, etc.) que facilita el mantenimiento y la escalabilidad.

2. **Separación de Responsabilidades**: Cada componente tiene una responsabilidad clara: los modelos representan datos, los servicios gestionan la lógica de negocio, y las pantallas manejan la interfaz de usuario.

3. **Integración con Firebase**: La aplicación aprovecha los servicios de Firebase (Auth, Firestore, Storage, Messaging) para proporcionar funcionalidades robustas de autenticación, base de datos, almacenamiento y notificaciones.

4. **Modelo de Datos Flexible**: Los modelos implementan métodos de serialización/deserialización que facilitan la persistencia en Firestore y permiten actualizaciones incrementales mediante `copyWith()`.

5. **Notificaciones en Tiempo Real**: El sistema implementa notificaciones push y locales para mantener a los usuarios informados sobre nuevos reportes y mensajes en chat.

6. **Gestión de Estado con Provider**: El uso de Provider permite una gestión de estado reactiva y eficiente, notificando cambios a los widgets que dependen de los servicios.

7. **Soporte Multiplataforma**: La aplicación está diseñada para funcionar en Android y Web, con estructura preparada para iOS, lo que amplía su alcance.

---

## RECOMENDACIONES

1. **Mejoras en el Modelo de Datos**:
   - Implementar validaciones más estrictas en los modelos
   - Agregar índices compuestos en Firestore para consultas más eficientes
   - Considerar normalización de datos para reducir duplicación

2. **Seguridad**:
   - Revisar y fortalecer las reglas de seguridad de Firestore
   - Implementar validación de datos en el cliente y servidor
   - Añadir rate limiting para prevenir abusos

3. **Performance**:
   - Implementar paginación para listas grandes de reportes
   - Cachear imágenes localmente para reducir consumo de ancho de banda
   - Optimizar consultas de Firestore con índices apropiados

4. **Funcionalidades Futuras**:
   - Implementar búsqueda de reportes por texto
   - Agregar estadísticas y dashboard analítico
   - Implementar geolocalización automática
   - Añadir soporte para múltiples idiomas (internacionalización)

5. **Testing**:
   - Implementar tests unitarios para servicios
   - Agregar tests de integración para flujos críticos
   - Tests de UI para pantallas principales

6. **Documentación del Código**:
   - Agregar documentación JSDoc/DartDoc más completa
   - Crear diagramas UML actualizados automáticamente
   - Documentar APIs y contratos de servicios

7. **Manejo de Errores**:
   - Implementar logging centralizado
   - Mejorar mensajes de error para usuarios
   - Agregar recuperación de errores automática cuando sea posible

8. **Cloud Functions**:
   - Desplegar Cloud Functions cuando se tenga acceso al plan Blaze
   - Implementar validaciones del lado del servidor
   - Automatizar notificaciones y otros procesos

---

## BIBLIOGRAFÍA

1. Martin, R. C. (2008). *Clean Code: A Handbook of Agile Software Craftsmanship*. Prentice Hall.

2. Fowler, M. (2012). *Patterns of Enterprise Application Architecture*. Addison-Wesley Professional.

3. Gamma, E., Helm, R., Johnson, R., & Vlissides, J. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software*. Addison-Wesley Professional.

4. Booch, G., Rumbaugh, J., & Jacobson, I. (2005). *The Unified Modeling Language User Guide* (2nd ed.). Addison-Wesley Professional.

5. Larman, C. (2004). *Applying UML and Patterns: An Introduction to Object-Oriented Analysis and Design and Iterative Development* (3rd ed.). Prentice Hall.

6. Fowler, M. (2002). *UML Distilled: A Brief Guide to the Standard Object Modeling Language* (3rd ed.). Addison-Wesley Professional.

7. Freeman, E., & Robson, E. (2004). *Head First Design Patterns*. O'Reilly Media.

8. Bloch, J. (2017). *Effective Java* (3rd ed.). Addison-Wesley Professional.

---

## WEBGRAFÍA

1. Flutter - Documentación Oficial. Disponible en: https://flutter.dev/docs

2. Firebase Documentation. Disponible en: https://firebase.google.com/docs

3. Cloud Firestore Documentation. Disponible en: https://firebase.google.com/docs/firestore

4. Firebase Authentication Documentation. Disponible en: https://firebase.google.com/docs/auth

5. Firebase Storage Documentation. Disponible en: https://firebase.google.com/docs/storage

6. Firebase Cloud Messaging Documentation. Disponible en: https://firebase.google.com/docs/cloud-messaging

7. Provider Package - Flutter. Disponible en: https://pub.dev/packages/provider

8. Flutter Map Package. Disponible en: https://pub.dev/packages/flutter_map

9. UML Diagram Examples. Disponible en: https://www.uml-diagrams.org/

10. Object-Oriented Design Principles. Disponible en: https://www.oodesign.com/

11. Dart Language Tour. Disponible en: https://dart.dev/guides/language/language-tour

12. Flutter Best Practices. Disponible en: https://flutter.dev/docs/development/ui/widgets-intro

13. Cloud Firestore Data Modeling. Disponible en: https://firebase.google.com/docs/firestore/manage-data/structure-data

14. Flutter State Management. Disponible en: https://flutter.dev/docs/development/data-and-backend/state-mgmt

15. Firebase Security Rules. Disponible en: https://firebase.google.com/docs/firestore/security/get-started

---

**Fecha de creación**: 2024
**Versión del documento**: 1.0
**Autor**: Equipo de Desarrollo SafeArea

