# 🔥 FCM Push Notifications Setup Guide

## 📱 **100% FREE Solution - NO Cloud Functions Needed!**

This chat app uses **Firebase Cloud Messaging (FCM) REST API** to send push notifications directly from Flutter, **without requiring Cloud Functions** or paid Firebase plans.

---

## ✅ **Why This Approach?**

| Feature | Cloud Functions (Blaze Plan) | Direct FCM HTTP (FREE) |
|---------|------------------------------|------------------------|
| Cost | Requires Blaze plan ($$$) | **100% FREE** |
| Setup | Complex | **Simple** |
| Scalability | High (1M+ users) | Good (1K-100K users) |
| Latency | Low (~100ms) | Medium (~500ms) |
| Security | High | Medium (server key in app) |

**For 1K users**: Direct FCM HTTP is **perfect** and completely **FREE**! ✅

---

## 🚀 **Setup Instructions (5 Minutes)**

### **Step 1: Get Firebase Server Key**

1. Go to **[Firebase Console](https://console.firebase.google.com/)**
2. Select your project (`chat_app2`)
3. Click **⚙️ Project Settings** (gear icon top-left)
4. Go to **Cloud Messaging** tab
5. Scroll down to **Cloud Messaging API (Legacy)**
6. Find **Server key** (starts with `AAAA...`)
7. Click **📋 Copy** button

**Screenshot Location**:
```
Firebase Console
  → Project Settings
    → Cloud Messaging
      → Cloud Messaging API (Legacy)
        → Server key: [COPY THIS]
```

---

### **Step 2: Add Server Key to App**

1. Open file: `lib/services/fcm_http_service.dart`
2. Find line 17:
   ```dart
   static const String _serverKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';
   ```
3. Replace `YOUR_FIREBASE_SERVER_KEY_HERE` with your actual server key:
   ```dart
   static const String _serverKey = 'AAAAxxxxxxx:APAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
   ```
4. Save the file

**⚠️ Security Note**: 
- For production apps, store the server key securely (not in code)
- Use environment variables or secure backend
- For small apps (<10K users), this approach is acceptable

---

### **Step 3: Test Notifications**

1. Run the app on **2 devices** (or 1 device + 1 emulator)
2. Log in with **different accounts** on each device
3. Send a message from Device A
4. **Device B should receive notification** 🎉

**Expected Behavior**:
- ✅ Notification appears when app is in background
- ✅ Notification appears when app is closed
- ✅ Notification appears when app is in foreground (as local notification)
- ✅ Tapping notification opens the chat

---

## 🛠️ **Troubleshooting**

### **Problem: No notifications received**

**Check #1: FCM Token**
```dart
// In your app, print FCM token
final fcmService = FCMService();
await fcmService.initialize();
print('FCM Token: ${fcmService.fcmToken}');
```
- Token should start with letters/numbers (not null)
- Token is saved in Firestore: `users/{uid}/fcmToken`

**Check #2: Server Key**
- Ensure you copied the **Server key** (not Project ID or App ID)
- Server key should start with `AAAA`
- Check for extra spaces or quotes

**Check #3: Internet Connection**
- Both sender and receiver must have internet
- Check Firebase Console > Cloud Messaging for delivery status

**Check #4: Android Permissions**
- Go to: Settings > Apps > Your App > Notifications
- Ensure notifications are **allowed**

---

### **Problem: "Server key not configured" error**

**Solution**:
1. Check `fcm_http_service.dart` line 17
2. Ensure server key is **NOT** `YOUR_FIREBASE_SERVER_KEY_HERE`
3. Server key should be actual Firebase server key (70+ characters)

---

### **Problem: Notifications work in foreground but not background**

**Solution (Android)**:
1. Check `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.firebase.messaging.default_notification_channel_id"
       android:value="high_importance_channel" />
   ```
2. Ensure this is inside `<application>` tag
3. Rebuild app: `flutter clean && flutter run`

---

## 📊 **How It Works**

```
User A sends message
    ↓
1. Store message in Firestore
    ↓
2. Get User B's FCM token from Firestore
    ↓
3. Call FCM REST API directly (HTTP POST)
    {
      "to": "user_b_fcm_token",
      "notification": {
        "title": "User A",
        "body": "Hello!"
      }
    }
    ↓
4. Firebase sends notification to User B's device
    ↓
5. User B receives notification 🎉
```

**No Cloud Functions needed!** Everything runs client-side. 🚀

---

## 🔒 **Security Considerations**

### **For Development/Small Apps (<10K users)**
- ✅ Direct HTTP approach is **acceptable**
- ✅ 100% FREE
- ✅ Simple to implement

### **For Production/Large Apps (>10K users)**
- ⚠️ Move server key to secure backend
- ⚠️ Use Firebase Admin SDK on backend
- ⚠️ Implement rate limiting
- ⚠️ Use Cloud Functions (requires Blaze plan)

**Our Recommendation**: 
- Use direct HTTP for **MVP and small apps**
- Upgrade to Cloud Functions when you have **revenue** or **>10K users**

---

## 💡 **Advanced Features (Optional)**

### **Send notifications for other actions**

**Image Messages**:
```dart
// After uploading image, send notification
FCMHttpService.sendNotificationToUser(
  userId: recipientUid,
  title: senderName,
  body: '📷 Sent an image',
  data: {'type': 'image', 'chatRoomId': chatRoomId},
  imageUrl: imageUrl, // Optional: show image in notification
);
```

**Voice Messages**:
```dart
FCMHttpService.sendNotificationToUser(
  userId: recipientUid,
  title: senderName,
  body: '🎤 Sent a voice message',
  data: {'type': 'voice', 'chatRoomId': chatRoomId},
);
```

**Group Messages**:
```dart
// Send to multiple users
await FCMHttpService.sendNotificationToMultipleUsers(
  userIds: ['user1', 'user2', 'user3'],
  title: groupName,
  body: '$senderName: $message',
  data: {'type': 'group', 'groupId': groupId},
);
```

---

## 📈 **Monitoring & Analytics**

### **Check notification delivery**:
1. Go to **[Firebase Console](https://console.firebase.google.com/)**
2. Navigate to **Cloud Messaging** > **Reports**
3. View:
   - Total notifications sent
   - Delivery rate
   - Open rate
   - Error rate

### **Debug logs** (in app):
```dart
// Enable debug mode
const bool kDebugMode = true;

// Check logs
if (kDebugMode) {
  debugPrint('✅ [FCM HTTP] Notification sent');
  debugPrint('❌ [FCM HTTP] Send error: ...');
}
```

---

## 🎓 **Learn More**

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Pricing](https://firebase.google.com/pricing)

---

## ✅ **Summary**

- ✅ **100% FREE** for unlimited users
- ✅ **No Cloud Functions** needed
- ✅ **Simple setup** (5 minutes)
- ✅ **Works great** for small-medium apps
- ✅ **Easy to upgrade** later if needed

**Just add your Firebase Server Key and you're done!** 🎉
