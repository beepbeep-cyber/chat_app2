import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// FCM HTTP Service - Send notifications WITHOUT Cloud Functions (100% FREE!)
/// 
/// Setup Instructions:
/// 1. Go to Firebase Console: https://console.firebase.google.com/
/// 2. Select your project
/// 3. Go to Project Settings (gear icon) > Cloud Messaging
/// 4. Find "Server key" under Cloud Messaging API (Legacy)
/// 5. Copy the server key
/// 6. Replace 'YOUR_FIREBASE_SERVER_KEY_HERE' below with your actual key
/// 
/// Security Note:
/// - Server key should be stored securely (not in code)
/// - For production, use Firebase Admin SDK or secure backend
/// - This approach is OK for small apps (<10K users)
class FCMHttpService {
  // ⚠️ REPLACE THIS WITH YOUR ACTUAL FIREBASE SERVER KEY
  // Get it from: Firebase Console > Project Settings > Cloud Messaging > Server key
  static const String _serverKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';
  
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';

  /// Send push notification directly to a user's device
  /// 
  /// Example usage:
  /// ```dart
  /// await FCMHttpService.sendNotification(
  ///   token: 'user_fcm_token',
  ///   title: 'New Message',
  ///   body: 'John sent you a message',
  ///   data: {'chatId': '123', 'senderId': 'abc'},
  /// );
  /// ```
  static Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      // Check if server key is configured
      if (_serverKey == 'YOUR_FIREBASE_SERVER_KEY_HERE') {
        if (kDebugMode) {
          debugPrint('❌ [FCM HTTP] Server key not configured!');
          debugPrint('💡 [FCM HTTP] Get your key from: Firebase Console > Project Settings > Cloud Messaging');
        }
        return false;
      }

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'to': token,
          'priority': 'high',
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'badge': '1',
            if (imageUrl != null) 'image': imageUrl,
          },
          if (data != null) 'data': data,
        }),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ [FCM HTTP] Notification sent successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [FCM HTTP] Failed to send notification');
          debugPrint('Status: ${response.statusCode}');
          debugPrint('Body: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM HTTP] Send error: $e');
      }
      return false;
    }
  }

  /// Send notification to user by userId (fetches token automatically)
  /// 
  /// Example usage:
  /// ```dart
  /// await FCMHttpService.sendNotificationToUser(
  ///   userId: 'recipient_user_id',
  ///   title: 'New Message',
  ///   body: 'You have a new message',
  ///   data: {'type': 'chat', 'chatId': '123'},
  /// );
  /// ```
  static Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      // Get user's FCM token from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM HTTP] User $userId has no FCM token');
        }
        return false;
      }

      // Send notification
      return await sendNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
        imageUrl: imageUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM HTTP] Send to user error: $e');
      }
      return false;
    }
  }

  /// Send notification to multiple users
  /// 
  /// Example usage:
  /// ```dart
  /// await FCMHttpService.sendNotificationToMultipleUsers(
  ///   userIds: ['user1', 'user2', 'user3'],
  ///   title: 'Group Message',
  ///   body: 'New message in group chat',
  /// );
  /// ```
  static Future<int> sendNotificationToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    int successCount = 0;

    for (final userId in userIds) {
      final success = await sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
      if (success) successCount++;
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (kDebugMode) {
      debugPrint('✅ [FCM HTTP] Sent $successCount/${userIds.length} notifications');
    }

    return successCount;
  }

  /// Send notification for new chat message
  /// 
  /// Automatically formats notification for chat messages
  static Future<bool> sendChatNotification({
    required String recipientUserId,
    required String senderName,
    required String messageText,
    required String chatRoomId,
  }) async {
    return await sendNotificationToUser(
      userId: recipientUserId,
      title: senderName,
      body: messageText,
      data: {
        'type': 'chat',
        'chatRoomId': chatRoomId,
        'senderId': recipientUserId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );
  }

  /// Send notification for video call
  static Future<bool> sendVideoCallNotification({
    required String recipientUserId,
    required String callerName,
    required String callerAvatar,
    required String channelName,
    required String chatRoomId,
  }) async {
    return await sendNotificationToUser(
      userId: recipientUserId,
      title: '📹 Cuộc gọi video đến',
      body: '$callerName đang gọi video cho bạn',
      data: {
        'type': 'video_call',
        'channelName': channelName,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'chatRoomId': chatRoomId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );
  }
}
