import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send notification when a new message is received
  static Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatRoomId,
    String? messageType,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Don't send notification to self
      if (receiverId == currentUser.uid) return;

      // Check if receiver has notifications enabled
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverData = receiverDoc.data();
      
      if (receiverData == null) return;

      // Check notification settings (default to true if not set)
      final notificationsEnabled = receiverData['notificationsEnabled'] ?? true;
      if (!notificationsEnabled) {
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('🔕 [Notification] User $receiverId has notifications disabled'); }
        }
        return;
      }

      // Get receiver's FCM token
      final fcmToken = receiverData['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('⚠️ [Notification] No FCM token for user $receiverId'); }
        }
        return;
      }

      // Format message preview based on type
      String messagePreview = message;
      if (messageType != null) {
        switch (messageType) {
          case 'image':
            messagePreview = '📷 Sent a photo';
            break;
          case 'video':
            messagePreview = '🎥 Sent a video';
            break;
          case 'audio':
            messagePreview = '🎵 Sent a voice message';
            break;
          case 'file':
            messagePreview = '📎 Sent a file';
            break;
          case 'location':
            messagePreview = '📍 Shared a location';
            break;
          default:
            // Truncate long messages
            if (message.length > 100) {
              messagePreview = '${message.substring(0, 100)}...';
            }
        }
      }

      // Store notification for Cloud Function to send
      await _firestore.collection('notifications').add({
        'token': fcmToken,
        'title': senderName,
        'body': messagePreview,
        'data': {
          'type': 'chat',
          'chatRoomId': chatRoomId,
          'senderId': currentUser.uid,
          'senderName': senderName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'receiverId': receiverId,
        'senderId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [Notification] Message notification queued for $receiverId'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [Notification] Error sending message notification: $e'); }
      }
    }
  }

  /// Send notification for incoming call
  static Future<void> sendCallNotification({
    required String receiverId,
    required String callerName,
    required String callType, // 'voice' or 'video'
    required String channelId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverData = receiverDoc.data();
      
      if (receiverData == null) return;

      final fcmToken = receiverData['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) return;

      final callTypeIcon = callType == 'video' ? '📹' : '📞';
      final callTypeText = callType == 'video' ? 'Video' : 'Voice';

      await _firestore.collection('notifications').add({
        'token': fcmToken,
        'title': '$callTypeIcon Incoming $callTypeText Call',
        'body': '$callerName is calling you',
        'data': {
          'type': 'call',
          'callType': callType,
          'channelId': channelId,
          'callerId': currentUser.uid,
          'callerName': callerName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'receiverId': receiverId,
        'senderId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
        'priority': 'high',
      });

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [Notification] Call notification sent to $receiverId'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [Notification] Error sending call notification: $e'); }
      }
    }
  }

  /// Send notification for group message
  static Future<void> sendGroupMessageNotification({
    required String groupId,
    required String groupName,
    required String senderName,
    required String message,
    required List<String> memberIds,
    String? messageType,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Format message preview
      String messagePreview = message;
      if (messageType != null) {
        switch (messageType) {
          case 'image':
            messagePreview = '📷 Sent a photo';
            break;
          case 'video':
            messagePreview = '🎥 Sent a video';
            break;
          case 'audio':
            messagePreview = '🎵 Sent a voice message';
            break;
          default:
            if (message.length > 80) {
              messagePreview = '${message.substring(0, 80)}...';
            }
        }
      }

      // Send to all members except sender
      for (final memberId in memberIds) {
        if (memberId == currentUser.uid) continue;

        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        final memberData = memberDoc.data();
        
        if (memberData == null) continue;

        final notificationsEnabled = memberData['notificationsEnabled'] ?? true;
        if (!notificationsEnabled) continue;

        final fcmToken = memberData['fcmToken'] as String?;
        if (fcmToken == null || fcmToken.isEmpty) continue;

        await _firestore.collection('notifications').add({
          'token': fcmToken,
          'title': groupName,
          'body': '$senderName: $messagePreview',
          'data': {
            'type': 'group_chat',
            'groupId': groupId,
            'groupName': groupName,
            'senderId': currentUser.uid,
            'senderName': senderName,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'receiverId': memberId,
          'senderId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [Notification] Group notification sent to ${memberIds.length - 1} members'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [Notification] Error sending group notification: $e'); }
      }
    }
  }

  /// Update notification settings for user
  static Future<void> updateNotificationSettings({
    required bool enabled,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.uid).update({
        'notificationsEnabled': enabled,
      });

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [Notification] Settings updated: enabled=$enabled'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [Notification] Error updating settings: $e'); }
      }
    }
  }
}
