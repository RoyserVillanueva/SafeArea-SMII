import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  // Tarea 13.3: Cargar mensajes antiguos (Paginación inversa)
  void loadOlderMessages(DocumentSnapshot lastDoc) {
    FirebaseFirestore.instance
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDoc)
        .limit(20);
  }
}
