/**
 * Firebase Cloud Functions for Chat App
 * 
 * Features:
 * 1. Auto-delete messages (runs every 5 minutes)
 * 2. Send push notifications
 * 
 * Deploy: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * Scheduled function to auto-delete old messages
 * Runs every 5 minutes
 */
exports.autoDeleteMessages = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('🗑️ [AutoDelete] Starting scheduled cleanup...');
    
    try {
      // Get all chatrooms with auto-delete enabled
      const chatroomsSnapshot = await db.collection('chatroom')
        .where('autoDeleteEnabled', '==', true)
        .get();
      
      if (chatroomsSnapshot.empty) {
        console.log('🗑️ [AutoDelete] No chatrooms with auto-delete enabled');
        return null;
      }
      
      console.log(`🗑️ [AutoDelete] Found ${chatroomsSnapshot.size} chatrooms to process`);
      
      let totalDeleted = 0;
      
      for (const chatroomDoc of chatroomsSnapshot.docs) {
        const chatRoomId = chatroomDoc.id;
        const data = chatroomDoc.data();
        const durationMinutes = data.autoDeleteDuration || 0;
        
        if (durationMinutes <= 0) {
          console.log(`🗑️ [AutoDelete] Skipping ${chatRoomId} - invalid duration`);
          continue;
        }
        
        console.log(`🗑️ [AutoDelete] Processing ${chatRoomId} - duration: ${durationMinutes} minutes`);
        
        // Calculate cutoff time
        const cutoffTime = new Date(Date.now() - durationMinutes * 60 * 1000);
        
        // Query old messages
        const oldMessagesSnapshot = await db.collection('chatroom')
          .doc(chatRoomId)
          .collection('chats')
          .where('timeStamp', '<', cutoffTime)
          .get();
        
        if (oldMessagesSnapshot.empty) {
          console.log(`🗑️ [AutoDelete] No old messages in ${chatRoomId}`);
          continue;
        }
        
        console.log(`🗑️ [AutoDelete] Found ${oldMessagesSnapshot.size} messages to delete in ${chatRoomId}`);
        
        // Batch delete
        const batch = db.batch();
        let deleteCount = 0;
        
        for (const messageDoc of oldMessagesSnapshot.docs) {
          batch.delete(messageDoc.ref);
          deleteCount++;
          
          // Commit every 450 documents (Firestore limit is 500)
          if (deleteCount >= 450) {
            await batch.commit();
            console.log(`🗑️ [AutoDelete] Committed batch of ${deleteCount} deletes`);
            totalDeleted += deleteCount;
            deleteCount = 0;
          }
        }
        
        // Commit remaining
        if (deleteCount > 0) {
          await batch.commit();
          totalDeleted += deleteCount;
          console.log(`🗑️ [AutoDelete] Committed final batch of ${deleteCount} deletes`);
        }
        
        // Update last message in chatroom
        await updateLastMessage(chatRoomId);
      }
      
      console.log(`✅ [AutoDelete] Cleanup complete. Total deleted: ${totalDeleted} messages`);
      return null;
      
    } catch (error) {
      console.error('❌ [AutoDelete] Error:', error);
      return null;
    }
  });

/**
 * Update last message in chatroom after deletion
 */
async function updateLastMessage(chatRoomId) {
  try {
    const latestMessages = await db.collection('chatroom')
      .doc(chatRoomId)
      .collection('chats')
      .orderBy('timeStamp', 'desc')
      .limit(1)
      .get();
    
    if (!latestMessages.empty) {
      const latestMessage = latestMessages.docs[0].data();
      await db.collection('chatroom').doc(chatRoomId).update({
        lastMessage: latestMessage.message || '',
        type: latestMessage.type || 'text',
      });
    } else {
      await db.collection('chatroom').doc(chatRoomId).update({
        lastMessage: '',
        type: 'text',
      });
    }
  } catch (error) {
    console.error(`❌ [AutoDelete] Error updating last message for ${chatRoomId}:`, error);
  }
}

/**
 * Send push notification when new message is received
 * Triggered when a new document is created in chats subcollection
 */
exports.sendChatNotification = functions.firestore
  .document('chatroom/{chatRoomId}/chats/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const chatRoomId = context.params.chatRoomId;
    
    console.log(`🔔 [Notification] New message in ${chatRoomId}`);
    
    try {
      // Get chatroom info to find recipient
      const chatroomDoc = await db.collection('chatroom').doc(chatRoomId).get();
      
      if (!chatroomDoc.exists) {
        console.log('🔔 [Notification] Chatroom not found');
        return null;
      }
      
      const chatroomData = chatroomDoc.data();
      const senderName = messageData.sendBy;
      
      // Determine recipient (the user who is NOT the sender)
      // This requires knowing user UIDs in the chatroom
      // For now, we'll use a simpler approach with chatHistory
      
      // Get sender UID
      const senderUid = messageData.senderUid;
      if (!senderUid) {
        console.log('🔔 [Notification] No sender UID');
        return null;
      }
      
      // Find users in this chatroom from chatHistory
      // The chatRoomId format is usually a combination of user UIDs
      const users = chatRoomId.split('_');
      const recipientUid = users.find(uid => uid !== senderUid);
      
      if (!recipientUid) {
        console.log('🔔 [Notification] Could not determine recipient');
        return null;
      }
      
      // Get recipient's FCM token
      const recipientDoc = await db.collection('users').doc(recipientUid).get();
      
      if (!recipientDoc.exists) {
        console.log('🔔 [Notification] Recipient not found');
        return null;
      }
      
      const recipientData = recipientDoc.data();
      const fcmToken = recipientData.fcmToken;
      
      if (!fcmToken) {
        console.log('🔔 [Notification] Recipient has no FCM token');
        return null;
      }
      
      // Prepare notification message
      let messageBody = 'New message';
      
      if (messageData.encrypted) {
        messageBody = '🔒 Encrypted message';
      } else if (messageData.type === 'text') {
        messageBody = messageData.message || 'New message';
      } else if (messageData.type === 'img') {
        messageBody = '📷 Image';
      } else if (messageData.type === 'voice') {
        messageBody = '🎤 Voice message';
      } else if (messageData.type === 'file') {
        messageBody = '📎 File';
      } else if (messageData.type === 'location') {
        messageBody = '📍 Location';
      }
      
      // Send notification
      const notification = {
        token: fcmToken,
        notification: {
          title: senderName || 'New Message',
          body: messageBody,
        },
        data: {
          type: 'chat',
          chatId: chatRoomId,
          senderId: senderUid,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            },
          },
        },
      };
      
      await admin.messaging().send(notification);
      console.log(`✅ [Notification] Sent to ${recipientUid}`);
      
      return null;
      
    } catch (error) {
      console.error('❌ [Notification] Error:', error);
      return null;
    }
  });

/**
 * Clean up user data when account is deleted
 */
exports.cleanupUserData = functions.auth.user().onDelete(async (user) => {
  console.log(`🗑️ [Cleanup] User deleted: ${user.uid}`);
  
  try {
    // Delete user document
    await db.collection('users').doc(user.uid).delete();
    
    // Delete user's chat history
    const chatHistorySnapshot = await db.collection('users')
      .doc(user.uid)
      .collection('chatHistory')
      .get();
    
    const batch = db.batch();
    chatHistorySnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    
    console.log(`✅ [Cleanup] User data cleaned up for ${user.uid}`);
    
  } catch (error) {
    console.error('❌ [Cleanup] Error:', error);
  }
});
