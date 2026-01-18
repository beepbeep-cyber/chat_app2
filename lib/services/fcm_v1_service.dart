import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:my_porject/config/fcm_config.dart';

/// FCM HTTP v1 API Service - Modern FCM implementation
/// 
/// ⚠️ QUAN TRỌNG:
/// 1. Tải Service Account JSON từ Firebase Console
/// 2. Đặt file vào: assets/service-account.json
/// 3. Thêm vào pubspec.yaml:
///    assets:
///      - assets/service-account.json
///
/// HƯỚNG DẪN LẤY SERVICE ACCOUNT JSON:
/// 1. Vào Firebase Console: https://console.firebase.google.com/
/// 2. Chọn project "chat_app2"
/// 3. Vào Project Settings (biểu tượng bánh răng) > Service accounts
/// 4. Click "Generate new private key"
/// 5. Tải file JSON về
/// 6. Đổi tên thành "service-account.json"
/// 7. Copy vào thư mục assets/ trong project Flutter
///
class FCMv1Service {
  static const String _projectId = 'chatapptest2-93793'; // ✅ Updated from google-services.json
  
  // FCM v1 API endpoint
  static String get _fcmEndpoint => 
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  /// Get OAuth 2.0 Access Token from Service Account JSON
  /// 
  /// Service Account JSON phải được đặt ở: assets/service-account.json
  static Future<String?> _getAccessToken() async {
    try {
      // Read service account JSON from assets
      final serviceAccountJson = await _loadServiceAccountJson();
      
      if (serviceAccountJson == null) {
        if (kDebugMode) {
          debugPrint('❌ [FCM v1] Service Account JSON not found!');
          debugPrint('💡 [FCM v1] Place service-account.json in assets/ folder');
        }
        return null;
      }

      // Create credentials from service account
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(
        serviceAccountJson,
      );

      // Get access token
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await auth.clientViaServiceAccount(
        accountCredentials,
        scopes,
      );

      final accessToken = authClient.credentials.accessToken.data;
      authClient.close();

      return accessToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM v1] Get access token error: $e');
      }
      return null;
    }
  }

  /// Load Service Account JSON from config
  static Future<Map<String, dynamic>?> _loadServiceAccountJson() async {
    try {
      // Load from FCMConfig (lib/config/fcm_config.dart)
      // This is configured with actual Service Account JSON
      return FCMConfig.serviceAccountJson;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM v1] Load service account error: $e');
      }
      return null;
    }
  }

  /// Send push notification using FCM v1 API
  /// 
  /// Example usage:
  /// ```dart
  /// await FCMv1Service.sendNotification(
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
      // Get access token
      final accessToken = await _getAccessToken();
      
      if (accessToken == null) {
        if (kDebugMode) {
          debugPrint('❌ [FCM v1] Failed to get access token');
        }
        return false;
      }

      // Prepare FCM v1 message payload
      final message = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
            if (imageUrl != null) 'image': imageUrl,
          },
          if (data != null) 'data': data,
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'channel_id': 'high_importance_channel',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'badge': 1,
              },
            },
          },
        },
      };

      // Send notification
      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ [FCM v1] Notification sent successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [FCM v1] Failed to send notification');
          debugPrint('Status: ${response.statusCode}');
          debugPrint('Body: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM v1] Send error: $e');
      }
      return false;
    }
  }

  /// Send notification to user by userId (fetches token automatically)
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
          debugPrint('⚠️ [FCM v1] User $userId has no FCM token');
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
        debugPrint('❌ [FCM v1] Send to user error: $e');
      }
      return false;
    }
  }

  /// Send notification to multiple users
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
      debugPrint('✅ [FCM v1] Sent $successCount/${userIds.length} notifications');
    }

    return successCount;
  }

  /// Send notification for new chat message
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
