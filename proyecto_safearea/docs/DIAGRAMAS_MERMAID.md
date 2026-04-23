# DIAGRAMAS MERMAID - PROYECTO SAFEAREA

Copia cada bloque de código y pégalo en [mermaid.live](https://mermaid.live) para generar el diagrama.

---

## 1. DIAGRAMA DE CASOS DE USO

```mermaid
graph TB
    subgraph Actores
        U["👤 Usuario"]
        A["👨‍💼 Administrador"]
    end

    subgraph "Módulo Autenticación"
        RF01["RF-01: Registrarse"]
        RF02["RF-02: Iniciar Sesión"]
        RF03["RF-03: Cerrar Sesión"]
        RF04["RF-04: Gestionar Perfil"]
    end

    subgraph "Módulo Reportes"
        RF05["RF-05: Crear Reporte"]
        RF06["RF-06: Categorizar Reporte"]
        RF07["RF-07: Cambiar Estado"]
        RF08["RF-08: Editar Reporte"]
        RF09["RF-09: Ver Listado Reportes"]
        RF10["RF-10: Ver Detalle Reporte"]
        RF11["RF-11: Adjuntar Imágenes"]
    end

    subgraph "Módulo Chat"
        RF12["RF-12: Chat por Zonas"]
        RF13["RF-13: Crear Grupo"]
        RF14["RF-14: Enviar Mensajes"]
        RF15["RF-15: Unirse/Salir Grupo"]
        RF16["RF-16: Chat Privado"]
    end

    subgraph "Módulo Administración"
        RF17["RF-17: Ver Dashboard"]
        RF18["RF-18: Gestionar Usuarios"]
        RF19["RF-19: Moderar Reportes"]
        RF20["RF-20: Eliminar Reportes"]
    end

    subgraph "Módulo Configuración"
        RF24["RF-24: Config. Notificaciones"]
        RF25["RF-25: Cambiar Tema"]
    end

    %% Conexiones Usuario
    U --> RF01
    U --> RF02
    U --> RF03
    U --> RF04
    U --> RF05
    U --> RF08
    U --> RF09
    U --> RF10
    U --> RF11
    U --> RF12
    U --> RF13
    U --> RF14
    U --> RF15
    U --> RF16
    U --> RF24
    U --> RF25

    %% Conexiones Administrador
    A --> RF01
    A --> RF02
    A --> RF03
    A --> RF04
    A --> RF05
    A --> RF09
    A --> RF10
    A --> RF17
    A --> RF18
    A --> RF19
    A --> RF20

    %% Relaciones include
    RF05 -.->|include| RF06
    RF05 -.->|include| RF11
```

---

## 2. DIAGRAMA DE CLASES / ENTIDAD-RELACIÓN

```mermaid
classDiagram
    class UserModel {
        +String id
        +String email
        +String name
        +String phone
        +String profileImage
        +DateTime createdAt
        +String role
        +bool isActive
        +bool isAdmin
        +toMap() Map
        +fromMap(Map) UserModel
        +copyWith() UserModel
    }

    class Report {
        +String id
        +String userId
        +String type
        +String title
        +String description
        +String location
        +String status
        +List~String~ images
        +DateTime createdAt
        +DateTime updatedAt
        +List~String~ verifiedBy
        +bool isActive
        +double latitude
        +double longitude
        +toMap() Map
        +fromMap(Map) Report
        +copyWith() Report
    }

    class ChatGroup {
        +String id
        +String name
        +String description
        +String createdBy
        +String createdByName
        +DateTime createdAt
        +List~String~ members
        +bool isPublic
        +String imageUrl
        +toMap() Map
        +fromMap(Map) ChatGroup
        +copyWith() ChatGroup
    }

    class Message {
        +String id
        +String userId
        +String userName
        +String text
        +String imageUrl
        +DateTime createdAt
        +String groupId
    }

    class AuthService {
        -FirebaseAuth _auth
        -FirebaseFirestore _firestore
        -UserModel _currentUser
        -bool _isLoading
        +login(email, password) Future~String~
        +register(email, password, name) Future~String~
        +logout() Future~void~
        +updateProfile(name, phone, profileImage) Future~String~
    }

    class ReportService {
        -FirebaseFirestore _firestore
        -String _selectedFilter
        -String _selectedStatus
        +createReport() Future~String~
        +updateReport(Report) Future~String~
        +changeReportStatus(id, status) Future~String~
        +getReports(filters) Stream~QuerySnapshot~
        +softDeleteReport(id) Future~String~
    }

    class ChatService {
        -FirebaseFirestore _firestore
        -String _currentGroupId
        +messagesStream(groupId) Stream~QuerySnapshot~
        +createGroup() Future~String~
        +joinGroup(groupId, userId) Future~String~
        +leaveGroup(groupId, userId) Future~String~
        +sendMessage() Future~String~
    }

    %% Relaciones entre entidades
    UserModel "1" --> "*" Report : crea
    UserModel "*" --> "*" ChatGroup : pertenece
    ChatGroup "1" --> "*" Message : contiene
    UserModel "1" --> "*" Message : envía

    %% Relaciones servicios
    AuthService ..> UserModel : gestiona
    ReportService ..> Report : gestiona
    ChatService ..> ChatGroup : gestiona
    ChatService ..> Message : gestiona
```

---

## 3. DIAGRAMA DE SECUENCIA - CREAR REPORTE

```mermaid
sequenceDiagram
    participant U as Usuario
    participant UI as AddReportScreen
    participant RS as ReportService
    participant FS as Firebase Storage
    participant FF as Cloud Firestore
    participant NS as NotificationService
    participant FCM as Firebase Cloud Messaging

    U->>UI: Abre pantalla Crear Reporte
    UI->>UI: Muestra formulario vacío

    U->>UI: Completa título, descripción, tipo
    U->>UI: Selecciona ubicación en mapa
    U->>UI: Adjunta imagen (opcional)

    U->>UI: Presiona Crear Reporte
    UI->>UI: Valida formulario

    alt Hay imagen adjunta
        UI->>FS: uploadFile(image)
        FS-->>UI: imageUrl
    end

    UI->>RS: createReport(userId, type, title, description, location, images)
    RS->>RS: _isLoading = true
    RS->>FF: collection reports doc set reportData
    FF-->>RS: Success

    RS->>NS: sendNewReportNotification(reportId, title, type)
    NS->>FCM: Enviar notificación a todos los usuarios
    FCM-->>NS: Notificación enviada

    RS->>RS: _isLoading = false
    RS-->>UI: null éxito

    UI->>UI: Muestra SnackBar Reporte creado
    UI->>U: Navigator.pop Vuelve a lista
```

---

## 4. DIAGRAMA DE SECUENCIA - LOGIN

```mermaid
sequenceDiagram
    participant U as Usuario
    participant UI as LoginScreen
    participant AS as AuthService
    participant FA as Firebase Auth
    participant FF as Cloud Firestore

    U->>UI: Abre la aplicación
    UI->>UI: Muestra formulario de login

    U->>UI: Ingresa email y contraseña
    U->>UI: Presiona Iniciar Sesión

    UI->>UI: Valida formulario
    UI->>AS: login(email, password)
    AS->>AS: _isLoading = true

    AS->>FA: signInWithEmailAndPassword(email, password)
    
    alt Credenciales válidas
        FA-->>AS: UserCredential
        AS->>FF: collection users doc uid get
        FF-->>AS: userData
        AS->>AS: _currentUser = UserModel.fromMap(userData)
        AS->>AS: _isLoading = false
        AS-->>UI: null éxito
        UI->>UI: Navigator.pushReplacement HomeScreen
        UI->>U: Muestra pantalla Home
    else Credenciales inválidas
        FA-->>AS: FirebaseAuthException
        AS->>AS: _isLoading = false
        AS-->>UI: Error mensaje
        UI->>UI: Muestra SnackBar con error
        UI->>U: Permanece en LoginScreen
    end
```

---

## 5. DIAGRAMA DE ARQUITECTURA

```mermaid
graph TB
    subgraph "PRESENTATION LAYER"
        S1[LoginScreen]
        S2[HomeScreen]
        S3[ReportsScreen]
        S4[ChatScreen]
        S5[ProfileScreen]
        W1[ReportCard]
        W2[AuthTextField]
        W3[FilterChip]
    end

    subgraph "STATE MANAGEMENT"
        AS[AuthService<br/>ChangeNotifier]
        RS[ReportService<br/>ChangeNotifier]
        CS[ChatService<br/>ChangeNotifier]
        TS[ThemeService<br/>ChangeNotifier]
        NS[NotificationService]
    end

    subgraph "DATA LAYER"
        UM[UserModel]
        RM[Report]
        CM[ChatGroup]
        MM[Message]
    end

    subgraph "FIREBASE"
        FA[Firebase Auth]
        FF[Cloud Firestore]
        FS[Firebase Storage]
        FCM[Cloud Messaging]
    end

    %% Presentation to State
    S1 --> AS
    S2 --> AS
    S3 --> RS
    S4 --> CS
    S5 --> AS
    W1 --> RS

    %% State to Data
    AS --> UM
    RS --> RM
    CS --> CM
    CS --> MM

    %% State to Firebase
    AS --> FA
    AS --> FF
    RS --> FF
    RS --> FS
    CS --> FF
    NS --> FCM

    %% Provider
    AS -.->|Provider| S1
    AS -.->|Provider| S2
    RS -.->|Provider| S3
    CS -.->|Provider| S4
    TS -.->|Provider| S2
```

---

## 6. DIAGRAMA ENTIDAD-RELACIÓN (BASE DE DATOS)

```mermaid
erDiagram
    USERS {
        string id PK
        string email
        string name
        string phone
        string profileImage
        datetime createdAt
        string role
        boolean isActive
    }

    REPORTS {
        string id PK
        string userId FK
        string type
        string title
        string description
        string location
        string status
        array images
        datetime createdAt
        datetime updatedAt
        array verifiedBy
        boolean isActive
        double latitude
        double longitude
    }

    CHAT_GROUPS {
        string id PK
        string name
        string description
        string createdBy FK
        string createdByName
        datetime createdAt
        array members
        boolean isPublic
        string imageUrl
    }

    MESSAGES {
        string id PK
        string groupId FK
        string userId FK
        string userName
        string text
        string imageUrl
        datetime createdAt
    }

    USERS ||--o{ REPORTS : "crea"
    USERS }o--o{ CHAT_GROUPS : "pertenece"
    CHAT_GROUPS ||--o{ MESSAGES : "contiene"
    USERS ||--o{ MESSAGES : "envía"
```

---

## Instrucciones de Uso

1. **Copiar el código**: Selecciona todo el contenido dentro del bloque de código (entre los \`\`\`mermaid y \`\`\`)

2. **Ir a Mermaid Live**: Abre [https://mermaid.live](https://mermaid.live)

3. **Pegar el código**: Pega el código en el editor de la izquierda

4. **Exportar**: Usa los botones de exportación para descargar como:
   - PNG (imagen)
   - SVG (vectorial)
   - PDF

5. **Incluir en LaTeX**: Para incluir en el documento LaTeX:
   ```latex
   \begin{figure}[h]
       \centering
       \includegraphics[width=0.9\textwidth]{diagrama_casos_uso.png}
       \caption{Diagrama de Casos de Uso}
   \end{figure}
   ```

---

*Generado el 27 de Noviembre de 2025*
