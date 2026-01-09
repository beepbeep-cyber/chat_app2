/**
 * Firebase Cloud Functions for Chat App
 * 
 * Features:
 * - Send FCM notifications when new notification document created
 * - Retry mechanism for failed sends
 * - Track delivery status
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Send FCM notification when a new notification document is created
 * 
 * Trigger: Firestore onCreate for /notifications/{notificationId}
 * 
 * Document structure:
 * {
 *   token: string,              // FCM token of receiver
 *   title: string,              // Notification title
 *   body: string,               // Notification body
 *   data: object,               // Custom data payload
 *   receiverId: string,         // User ID of receiver
 *   senderId: string,           // User ID of sender
 *   createdAt: timestamp,       // When notification was created
 *   sent: boolean,              // Has been sent?
 *   sentAt: timestamp,          // When it was sent
 *   error: string,              // Error message if failed
 * }
 */
exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const data = snap.data();
      const notificationId = context.params.notificationId;

      console.log(`📨 [FCM] Processing notification ${notificationId}`);
      console.log(`📨 [FCM] Receiver: ${data.receiverId}`);
      console.log(`📨 [FCM] Sender: ${data.senderId}`);

      // Skip if already sent
      if (data.sent) {
        console.log(`⏭️ [FCM] Already sent, skipping`);
        return null;
      }

      // Validate required fields
      if (!data.token || !data.title || !data.body) {
        console.error(`❌ [FCM] Missing required fields`);
        await snap.ref.update({
          error: 'Missing required fields: token, title, or body',
          sent: false,
        });
        return null;
      }

      // Build FCM message
      const message = {
        token: data.token,
        notification: {
          title: data.title,
          body: data.body,
        },
        data: {
          ...data.data,
          notificationId: notificationId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: data.priority === 'high' ? 'high' : 'normal',
          notification: {
            channelId: 'high_importance_channel',
            priority: data.priority === 'high' ? 'high' : 'default',
            sound: 'default',
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      console.log(`📤 [FCM] Sending notification...`);

      // Send notification via FCM
      const response = await admin.messaging().send(message);

      console.log(`✅ [FCM] Sent successfully: ${response}`);

      // Update document to mark as sent
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });

      return { success: true, messageId: response };

    } catch (error) {
      console.error(`❌ [FCM] Error sending notification:`, error);

      // Check error type
      let errorMessage = error.message || 'Unknown error';
      let shouldRetry = false;

      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        errorMessage = 'Invalid or expired FCM token';
        console.log(`🔑 [FCM] Token invalid, should remove from user`);
        
        // Optionally: Remove invalid token from user document
        const data = snap.data();
        if (data.receiverId) {
          try {
            await admin.firestore()
              .collection('users')
              .doc(data.receiverId)
              .update({
                fcmToken: admin.firestore.FieldValue.delete(),
              });
            console.log(`🗑️ [FCM] Removed invalid token from user ${data.receiverId}`);
          } catch (e) {
            console.error(`❌ [FCM] Failed to remove token:`, e);
          }
        }
      } else if (error.code === 'messaging/message-rate-exceeded') {
        errorMessage = 'FCM rate limit exceeded';
        shouldRetry = true;
      } else if (error.code === 'messaging/internal-error') {
        errorMessage = 'FCM internal error';
        shouldRetry = true;
      }

      // Update document with error
      await snap.ref.update({
        error: errorMessage,
        errorCode: error.code || 'unknown',
        sent: false,
        shouldRetry: shouldRetry,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Don't throw error - let it fail gracefully
      return { success: false, error: errorMessage };
    }
  });

/**
 * Retry failed notifications (scheduled function)
 * 
 * Runs every 5 minutes to retry failed notifications
 */
exports.retryFailedNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log(`🔄 [FCM] Checking for failed notifications to retry...`);

    try {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

      // Find notifications that failed and should be retried
      const failedNotifications = await admin.firestore()
        .collection('notifications')
        .where('sent', '==', false)
        .where('shouldRetry', '==', true)
        .where('lastAttemptAt', '<', fiveMinutesAgo)
        .limit(100)
        .get();

      if (failedNotifications.empty) {
        console.log(`✅ [FCM] No failed notifications to retry`);
        return null;
      }

      console.log(`🔄 [FCM] Found ${failedNotifications.size} notifications to retry`);

      const promises = failedNotifications.docs.map(async (doc) => {
        const data = doc.data();
        
        const message = {
          token: data.token,
          notification: {
            title: data.title,
            body: data.body,
          },
          data: data.data || {},
        };

        try {
          const response = await admin.messaging().send(message);
          
          await doc.ref.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            messageId: response,
            error: admin.firestore.FieldValue.delete(),
            shouldRetry: false,
          });

          console.log(`✅ [FCM] Retry successful: ${doc.id}`);
        } catch (error) {
          console.error(`❌ [FCM] Retry failed: ${doc.id}`, error.message);
          
          await doc.ref.update({
            lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            retryCount: admin.firestore.FieldValue.increment(1),
          });
        }
      });

      await Promise.all(promises);
      console.log(`🔄 [FCM] Retry batch complete`);

      return null;
    } catch (error) {
      console.error(`❌ [FCM] Retry function error:`, error);
      return null;
    }
  });

/**
 * Clean up old notifications (scheduled function)
 * 
 * Runs daily to delete notifications older than 30 days
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log(`🧹 [FCM] Cleaning up old notifications...`);

    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      const oldNotifications = await admin.firestore()
        .collection('notifications')
        .where('createdAt', '<', thirtyDaysAgo)
        .limit(500)
        .get();

      if (oldNotifications.empty) {
        console.log(`✅ [FCM] No old notifications to clean up`);
        return null;
      }

      console.log(`🧹 [FCM] Deleting ${oldNotifications.size} old notifications`);

      const batch = admin.firestore().batch();
      oldNotifications.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`✅ [FCM] Cleanup complete`);

      return null;
    } catch (error) {
      console.error(`❌ [FCM] Cleanup error:`, error);
      return null;
    }
  });

/**
 * Send notification to topic
 * 
 * Callable function for sending notifications to FCM topics
 */
exports.sendTopicNotification = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { topic, title, body, customData } = data;

  if (!topic || !title || !body) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: topic, title, body'
    );
  }

  try {
    const message = {
      topic: topic,
      notification: {
        title: title,
        body: body,
      },
      data: customData || {},
    };

    const response = await admin.messaging().send(message);

    console.log(`✅ [FCM] Topic notification sent to ${topic}: ${response}`);

    return { success: true, messageId: response };
  } catch (error) {
    console.error(`❌ [FCM] Topic notification error:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
