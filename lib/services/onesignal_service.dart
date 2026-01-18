import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// OneSignal Push Notification Service
/// 
/// 100% FREE - No credit card needed!
/// Works when app is: Foreground, Background, Killed
class OneSignalService {
  // ✅ OneSignal App ID (from OneSignal dashboard)
  static const String _appId = 'd431e013-1ca9-4d2e-847e-6fabac5131d6';
  
  // ⚠️ OneSignal REST API Key (get from OneSignal Settings > Keys & IDs)
  // For now, we'll get it later. OneSignal can work without it for basic features.
  static const String? _restApiKey = null; // Will be set later
  
  /// Initialize OneSignal
  /// Call this in main.dart before runApp()
  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        debugPrint('🔔 [OneSignal] Initializing...');
      }
      
      // Initialize OneSignal with App ID
      OneSignal.initialize(_appId);
      
      // Request notification permission (will show system prompt)
      OneSignal.Notifications.requestPermission(true);
      
      // Add notification click listener
      OneSignal.Notifications.addClickListener((event) {
        if (kDebugMode) {
          debugPrint('🔔 [OneSignal] Notification clicked!');
          debugPrint('🔔 [OneSignal] Data: ${event.notification.additionalData}');
        }
        
        // Handle notification tap
        final data = event.notification.additionalData;
        if (data != null) {
          _handleNotificationTap(data);
        }
      });
      
      if (kDebugMode) {
        debugPrint('✅ [OneSignal] Initialized successfully');
        
        // Log player ID when available
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          debugPrint('🔔 [OneSignal] Player ID: $playerId');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OneSignal] Initialization error: $e');
      }
    }
  }
  
  /// Save OneSignal Player ID to Firestore
  /// Call this after user login
  static Future<void> savePlayerIdToFirestore(String userId) async {
    try {
      // Get OneSignal Player ID
      final playerId = OneSignal.User.pushSubscription.id;
      
      if (playerId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [OneSignal] Player ID not available yet');
        }
        return;
      }
      
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'oneSignalPlayerId': playerId,
        'oneSignalPlayerIdUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ [OneSignal] Player ID saved to Firestore: $playerId');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OneSignal] Save Player ID error: $e');
      }
    }
  }
  
  /// Send notification to a user
  /// 
  /// Note: This requires OneSignal REST API Key
  /// For now, notifications will be sent via Firestore triggers (see below)
  static Future<bool> sendNotification({
    required String recipientPlayerId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (_restApiKey == null) {
      if (kDebugMode) {
        debugPrint('⚠️ [OneSignal] REST API Key not configured');
        debugPrint('💡 [OneSignal] Get it from: OneSignal Dashboard > Settings > Keys & IDs');
      }
      return false;
    }
    
    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      
      final body = {
        'app_id': _appId,
        'include_player_ids': [recipientPlayerId],
        'headings': {'en': title},
        'contents': {'en': message},
        if (data != null) 'data': data,
        'android_channel_id': 'high_importance_channel',
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ [OneSignal] Notification sent successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [OneSignal] Failed to send notification');
          debugPrint('Status: ${response.statusCode}');
          debugPrint('Body: ${response.body}');
        }
        return false;
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OneSignal] Send notification error: $e');
      }
      return false;
    }
  }
  
  /// Send notification to user by Firestore userId
  static Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's OneSignal Player ID from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final playerId = userDoc.data()?['oneSignalPlayerId'] as String?;
      
      if (playerId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [OneSignal] User $userId has no Player ID');
        }
        return false;
      }
      
      // Send notification
      return await sendNotification(
        recipientPlayerId: playerId,
        title: title,
        message: message,
        data: data,
      );
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OneSignal] Send to user error: $e');
      }
      return false;
    }
  }
  
  /// Handle notification tap
  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('🔔 [OneSignal] Handling notification tap...');
      debugPrint('🔔 [OneSignal] Type: ${data['type']}');
    }
    
    // TODO: Navigate to appropriate screen based on notification type
    // Example:
    // if (data['type'] == 'chat') {
    //   final chatRoomId = data['chatRoomId'];
    //   // Navigate to ChatScreen(chatRoomId)
    // }
  }
  
  /// Get current OneSignal Player ID
  static String? get playerId => OneSignal.User.pushSubscription.id;
  
  /// Check if user is subscribed to push notifications
  static bool get isSubscribed => OneSignal.User.pushSubscription.id != null;
}
