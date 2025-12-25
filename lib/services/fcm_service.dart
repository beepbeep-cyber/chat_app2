import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    if (kDebugMode) { debugPrint('🔔 [FCM] Background message: ${message.messageId}'); }
    if (kDebugMode) { debugPrint('🔔 [FCM] Title: ${message.notification?.title}'); }
    if (kDebugMode) { debugPrint('🔔 [FCM] Body: ${message.notification?.body}'); }
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Request permission
      await _requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle message opened app
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from notification
      await _checkInitialMessage();

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [FCM] Service initialized successfully'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [FCM] Initialization error: $e'); }
      }
    }
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🔔 [FCM] Permission status: ${settings.authorizationStatus}'); }
    }
  }

  /// Initialize local notifications for foreground
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Get FCM token
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🔑 [FCM] Token: $_fcmToken'); }
      }

      // Save token to Firestore
      await _saveTokenToFirestore(_fcmToken);
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [FCM] Get token error: $e'); }
      }
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) async {
    _fcmToken = token;
    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🔄 [FCM] Token refreshed: $token'); }
    }
    await _saveTokenToFirestore(token);
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [FCM] Token saved to Firestore'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [FCM] Save token error: $e'); }
      }
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🔔 [FCM] Foreground message received'); }
      if (kDebugMode) { debugPrint('🔔 [FCM] Title: ${message.notification?.title}'); }
      if (kDebugMode) { debugPrint('🔔 [FCM] Body: ${message.notification?.body}'); }
    }

    // Show local notification
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'New Message',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle message opened app
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🔔 [FCM] App opened from notification'); }
      if (kDebugMode) { debugPrint('🔔 [FCM] Data: ${message.data}'); }
    }
    _navigateToScreen(message.data);
  }

  /// Check initial message when app opened from terminated state
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🔔 [FCM] App opened from terminated state'); }
      }
      _navigateToScreen(initialMessage.data);
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateToScreen(data);
      } catch (e) {
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('❌ [FCM] Parse payload error: $e'); }
        }
      }
    }
  }

  /// Navigate to appropriate screen based on notification data
  void _navigateToScreen(Map<String, dynamic> data) {
    // Extract notification type and navigate accordingly
    final type = data['type'] as String?;
    final chatId = data['chatId'] as String?;
    final senderId = data['senderId'] as String?;

    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🔔 [FCM] Navigate - Type: $type, ChatId: $chatId, SenderId: $senderId'); }
    }

    // TODO: Implement navigation based on notification type
    // Example:
    // if (type == 'chat' && chatId != null) {
    //   navigatorKey.currentState?.push(MaterialPageRoute(
    //     builder: (_) => ChatScreen(chatId: chatId),
    //   ));
    // }
  }

  /// Send notification to a specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null) {
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('⚠️ [FCM] User $userId has no FCM token'); }
        }
        return;
      }

      // Store notification in Firestore for Cloud Function to send
      await FirebaseFirestore.instance.collection('notifications').add({
        'token': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [FCM] Notification queued for user $userId'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [FCM] Send notification error: $e'); }
      }
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [FCM] Subscribed to topic: $topic'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [FCM] Subscribe error: $e'); }
      }
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [FCM] Unsubscribed from topic: $topic'); }
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [FCM] Unsubscribe error: $e'); }
      }
    }
  }

  /// Clear FCM token on logout
  Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('✅ [FCM] Token cleared from Firestore'); }
        }
      } catch (e) {
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('❌ [FCM] Clear token error: $e'); }
        }
      }
    }
    await _messaging.deleteToken();
    _fcmToken = null;
  }
}
