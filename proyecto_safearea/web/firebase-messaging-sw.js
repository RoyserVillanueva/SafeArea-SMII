/* eslint-disable no-undef */
// Firebase Messaging service worker for web (Flutter)
// Uses compat builds to match flutterfire messaging on web

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Initialize Firebase app in the service worker using the same options as in firebase_options.dart
firebase.initializeApp({
  apiKey: 'AIzaSyBCf1IWMngdFJjVmtypzcuOW7rOlOwLMFE',
  appId: '1:715221615315:web:2c2dba41474d0a29608a26',
  messagingSenderId: '715221615315',
  projectId: 'royserfirebase',
  authDomain: 'royserfirebase.firebaseapp.com',
  storageBucket: 'royserfirebase.firebasestorage.app',
});

// Retrieve firebase messaging
const messaging = firebase.messaging();

// Optional: Background messages handler (shows a simple notification)
messaging.onBackgroundMessage((payload) => {
  const title = payload?.notification?.title || 'Nueva notificación';
  const body = payload?.notification?.body || '';
  const options = { body };
  self.registration.showNotification(title, options);
});


