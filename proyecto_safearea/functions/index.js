const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function que procesa la cola de notificaciones
 * Se ejecuta cuando se crea un documento en 'notification_queue'
 */
exports.processNotificationQueue = functions.firestore
  .document('notification_queue/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();
    const { token, notification, data } = notificationData;

    // Verificar que tengamos los datos necesarios
    if (!token || !notification) {
      console.error('Datos de notificación incompletos');
      return null;
    }

    // Preparar el mensaje de FCM
    const message = {
      token: token,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: data?.type || 'general',
        id: data?.id || '',
        ...(data?.image && { image: data.image }),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'safearea_channel',
          ...(data?.image && { imageUrl: data.image }),
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body,
            },
            sound: 'default',
          },
        },
        ...(data?.image && {
          fcmOptions: {
            image: data.image,
          },
        }),
      },
    };

    try {
      // Enviar la notificación usando FCM
      const response = await admin.messaging().send(message);
      console.log('Notificación enviada exitosamente:', response);

      // Eliminar el documento de la cola después de enviarlo
      await snap.ref.delete();
      return null;
    } catch (error) {
      console.error('Error al enviar notificación:', error);
      
      // Si el token es inválido, eliminar el documento
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        console.log('Token inválido, eliminando de la cola');
        await snap.ref.delete();
      }
      
      return null;
    }
  });

