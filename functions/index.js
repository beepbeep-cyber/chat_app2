/**
 * Firebase Cloud Functions for Push Notifications
 * 
 * This function is triggered when a new message is added to Firestore
 * and sends a push notification to the recipient via FCM v1 API
 * 
 * SETUP:
 * 1. Install: npm install firebase-admin firebase-functions
 * 2. Deploy: firebase deploy --only functions
 * 3. Done! Notifications work automatically
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Send FCM notification when new message is created
 * 
 * Trigger: Firestore onCreate at chatroom/{chatRoomId}/chats/{messageId}
 */
exports.sendChatNotification = functions.firestore
  .document('chatroom/{chatRoomId}/chats/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const message = snap.data();
      const chatRoomId = context.params.chatRoomId;
      
      console.log('📨 New message detected:', {
        chatRoomId,
        sendBy: message.sendBy,
        type: message.type,
      });

      // Skip if message is from system or empty
      if (!message.sendBy || message.type === 'system') {
        console.log('⏭️ Skipping system message');
        return null;
      }

      // Get sender info
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(message.sendBy)
        .get();

      if (!senderDoc.exists) {
        console.log('⚠️ Sender not found:', message.sendBy);
        return null;
      }

      const sender = senderDoc.data();
      const senderName = sender.name || 'Someone';

      // Find recipient (the other user in chatroom)
      const chatRoomDoc = await admin.firestore()
        .collection('chatroom')
        .doc(chatRoomId)
        .get();

      if (!chatRoomDoc.exists) {
        console.log('⚠️ Chatroom not found:', chatRoomId);
        return null;
      }

      const chatRoom = chatRoomDoc.data();
      const recipientId = chatRoom.user1 === message.sendBy 
        ? chatRoom.user2 
        : chatRoom.user1;

      // Get recipient's FCM token
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();

      if (!recipientDoc.exists) {
        console.log('⚠️ Recipient not found:', recipientId);
        return null;
      }

      const recipient = recipientDoc.data();
      const fcmToken = recipient.fcmToken;

      if (!fcmToken) {
        console.log('⚠️ Recipient has no FCM token:', recipientId);
        return null;
      }

      // Format message text based on type
      let notificationBody;
      switch (message.type) {
        case 'text':
          notificationBody = message.message;
          break;
        case 'img':
          notificationBody = '📷 Sent a photo';
          break;
        case 'location':
          notificationBody = '📍 Shared a location';
          break;
        case 'voice':
          notificationBody = '🎤 Sent a voice message';
          break;
        default:
          notificationBody = 'Sent a message';
      }

      // Send FCM v1 notification
      const payload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: notificationBody,
        },
        data: {
          type: 'chat',
          chatRoomId: chatRoomId,
          senderId: message.sendBy,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            sound: 'default',
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

      const response = await admin.messaging().send(payload);
      console.log('✅ Notification sent successfully:', response);

      return response;

    } catch (error) {
      console.error('❌ Error sending notification:', error);
      return null;
    }
  });

/**
 * Send video call notification (manual trigger from Flutter app)
 * 
 * HTTP Callable Function
 * 
 * Usage from Flutter:
 * final callable = FirebaseFunctions.instance.httpsCallable('sendVideoCallNotification');
 * await callable.call({
 *   'recipientId': 'user_id',
 *   'callerName': 'John Doe',
 *   'channelName': 'channel_123',
 * });
 */
exports.sendVideoCallNotification = functions.https.onCall(async (data, context) => {
  try {
    const { recipientId, callerName, callerAvatar, channelName, chatRoomId } = data;

    // Validate input
    if (!recipientId || !callerName) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'recipientId and callerName are required'
      );
    }

    // Get recipient's FCM token
    const recipientDoc = await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .get();

    if (!recipientDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Recipient not found');
    }

    const recipient = recipientDoc.data();
    const fcmToken = recipient.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError('failed-precondition', 'Recipient has no FCM token');
    }

    // Send notification
    const payload = {
      token: fcmToken,
      notification: {
        title: '📹 Incoming Video Call',
        body: `${callerName} is calling you`,
      },
      data: {
        type: 'video_call',
        channelName: channelName || '',
        callerName: callerName,
        callerAvatar: callerAvatar || '',
        chatRoomId: chatRoomId || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
        },
      },
    };

    const response = await admin.messaging().send(payload);
    console.log('✅ Video call notification sent:', response);

    return { success: true, messageId: response };

  } catch (error) {
    console.error('❌ Error sending video call notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Clean up old messages (scheduled function)
 * Runs daily at midnight
 */
exports.cleanupOldMessages = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('Asia/Ho_Chi_Minh')
  .onRun(async (context) => {
    try {
      const db = admin.firestore();
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 30); // 30 days ago

      console.log('🧹 Cleaning up messages older than:', cutoffDate);

      const snapshot = await db.collectionGroup('chats')
        .where('timeStamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
        .get();

      const batch = db.batch();
      snapshot.docs.forEach(doc => batch.delete(doc.ref));

      await batch.commit();
      console.log(`✅ Deleted ${snapshot.size} old messages`);

      return null;
    } catch (error) {
      console.error('❌ Error cleaning up messages:', error);
      return null;
    }
  });
