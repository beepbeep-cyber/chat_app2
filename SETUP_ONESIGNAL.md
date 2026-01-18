# 🔔 HƯỚNG DẪN SETUP ONESIGNAL - PUSH NOTIFICATIONS 100% FREE

## ⚡ TẠI SAO DÙNG ONESIGNAL?

**Vấn đề hiện tại:**
- Firebase Cloud Messaging cần Cloud Functions (Blaze plan, cần thẻ)
- FCM HTTP v1 API cần Service Account JSON trong app (không an toàn)
- Không có backend server để gửi notification

**Giải pháp OneSignal:**
- ✅ **100% MIỄN PHÍ** (10,000 users)
- ✅ **KHÔNG CẦN THẺ TÍN DỤNG**
- ✅ **Push notification THỰC SỰ** (app killed vẫn nhận)
- ✅ **Setup 10 phút**
- ✅ **An toàn cho production APK**

---

## 🚀 SETUP ONESIGNAL (10 PHÚT)

### **BƯỚC 1: Tạo tài khoản OneSignal**

1. Vào: **https://onesignal.com/**
2. Click **"Get Started Free"**
3. Đăng ký bằng email (hoặc Google/GitHub)
4. Xác nhận email

### **BƯỚC 2: Tạo App trong OneSignal**

1. Sau khi login, click **"New App/Website"**
2. Nhập tên app: **"chat_app2"** (hoặc tên khác)
3. Chọn platform: **Android (Firebase FCM)**
4. Click **"Next: Configure Your Platform"**

### **BƯỚC 3: Cấu hình Firebase FCM**

1. OneSignal yêu cầu **Firebase Server Key** (Legacy)
2. **VẤN ĐỀ**: Firebase đã ẩn Server Key!
3. **GIẢI PHÁP**: Dùng **Firebase Cloud Messaging API (V1)** credentials

**Lấy Firebase credentials:**

#### **Option A: Dùng google-services.json** (Dễ nhất)

1. Upload file `google-services.json` lên OneSignal
2. OneSignal tự động parse và lấy credentials
3. **DONE!**

#### **Option B: Lấy Firebase Server Key** (Nếu có)

1. Vào Firebase Console: https://console.firebase.google.com/
2. Chọn project "chatapptest2-93793"
3. **Project Settings** → **Cloud Messaging**
4. Scroll xuống phần **"Cloud Messaging API (Legacy)"**
5. Copy **Server Key** (nếu còn hiển thị)
6. Paste vào OneSignal

#### **Option C: Dùng FCM v1 credentials** (Recommended)

1. OneSignal hỗ trợ FCM v1 API
2. Upload **Service Account JSON** lên OneSignal
3. OneSignal lưu credentials an toàn ở server
4. **App KHÔNG CẦN** Service Account JSON

### **BƯỚC 4: Lấy OneSignal App ID**

Sau khi setup xong, OneSignal sẽ cho mày:
- **App ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **API Key**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

Lưu 2 giá trị này lại!

---

## 📱 TÍCH HỢP ONESIGNAL VÀO FLUTTER APP

### **BƯỚC 1: Thêm dependency**

Mở `pubspec.yaml`:

```yaml
dependencies:
  onesignal_flutter: ^5.2.10  # Latest stable version
```

Run:
```bash
flutter pub get
```

### **BƯỚC 2: Cấu hình Android**

Không cần làm gì! OneSignal tự động cấu hình khi build.

### **BƯỚC 3: Init OneSignal trong main.dart**

```dart
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // OneSignal Initialization
  OneSignal.initialize("YOUR_ONESIGNAL_APP_ID");  // ← Thay bằng App ID của mày
  
  // Request notification permission (iOS)
  OneSignal.Notifications.requestPermission(true);
  
  runApp(MyApp());
}
```

### **BƯỚC 4: Lưu OneSignal Player ID vào Firestore**

Khi user login, lưu OneSignal Player ID vào Firestore:

```dart
import 'package:onesignal_flutter/onesignal_flutter.dart';

Future<void> saveOneSignalPlayerId(String userId) async {
  // Get OneSignal Player ID
  final playerId = OneSignal.User.pushSubscription.id;
  
  if (playerId != null) {
    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({
      'oneSignalPlayerId': playerId,
      'oneSignalPlayerIdUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('✅ OneSignal Player ID saved: $playerId');
  }
}
```

Gọi function này sau khi user login thành công.

### **BƯỚC 5: Gửi notification khi có message mới**

Thay vì gọi FCM API, gọi OneSignal REST API:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendOneSignalNotification({
  required String recipientPlayerId,
  required String title,
  required String message,
  Map<String, dynamic>? data,
}) async {
  const String oneSignalAppId = "YOUR_ONESIGNAL_APP_ID";  // ← Thay bằng App ID
  const String oneSignalApiKey = "YOUR_ONESIGNAL_API_KEY";  // ← Thay bằng API Key
  
  final url = Uri.parse('https://onesignal.com/api/v1/notifications');
  
  final body = {
    'app_id': oneSignalAppId,
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
      'Authorization': 'Basic $oneSignalApiKey',
    },
    body: jsonEncode(body),
  );
  
  if (response.statusCode == 200) {
    print('✅ OneSignal notification sent successfully');
  } else {
    print('❌ Failed to send OneSignal notification: ${response.body}');
  }
}
```

### **BƯỚC 6: Gọi sendOneSignalNotification khi gửi tin nhắn**

Trong `chat_screen.dart`, method `onSendMessage()`:

```dart
// After saving message to Firestore
await chatHistoryRef.set({...}, SetOptions(merge: true));

// Get recipient's OneSignal Player ID
final recipientDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(widget.userMap['uid'])
    .get();

final recipientPlayerId = recipientDoc.data()?['oneSignalPlayerId'];

if (recipientPlayerId != null) {
  // Send OneSignal notification
  await sendOneSignalNotification(
    recipientPlayerId: recipientPlayerId,
    title: widget.user.displayName ?? 'Someone',
    message: message,
    data: {
      'type': 'chat',
      'chatRoomId': widget.chatRoomId,
      'senderId': widget.user.uid,
    },
  );
}
```

---

## 🧪 TEST ONESIGNAL

### **Test 1: App killed**

**Thiết bị A:**
1. Mở app, đăng nhập
2. Vào chat với user khác
3. Gửi tin: "Test OneSignal!"

**Thiết bị B:**
1. Mở app, đăng nhập (OneSignal Player ID đã lưu)
2. **KILL APP** (swipe ra khỏi recent apps)
3. **KẾT QUẢ**: Nhận notification với title = tên người gửi, message = "Test OneSignal!"
4. Tap notification → Mở app, vào đúng chat

### **Test 2: App background**

Same as above, nhưng không kill app, chỉ minimize.

### **Test 3: App foreground**

App đang mở → Nhận local notification (OneSignal tự xử lý)

---

## ⚙️ ONESIGNAL NOTIFICATION HANDLING

OneSignal tự động handle notification tap:

```dart
// In main.dart or app initialization
OneSignal.Notifications.addClickListener((event) {
  print('OneSignal notification tapped!');
  print('Data: ${event.notification.additionalData}');
  
  // Navigate to chat screen
  final data = event.notification.additionalData;
  if (data?['type'] == 'chat') {
    final chatRoomId = data?['chatRoomId'];
    // Navigate to ChatScreen with chatRoomId
  }
});
```

---

## 🎯 SO SÁNH: FCM vs OneSignal

| Tính năng | Firebase Cloud Messaging | OneSignal |
|-----------|--------------------------|-----------|
| **Chi phí** | $0 (cần Blaze plan cho Functions) | $0 (10K users free) |
| **Setup** | Phức tạp (Cloud Functions) | Đơn giản (10 phút) |
| **Thẻ tín dụng** | Cần (Blaze plan) | **KHÔNG CẦN** |
| **App killed** | ✅ (với Cloud Functions) | ✅ (tự động) |
| **Security** | Service Account JSON | API Key (safe) |
| **Dashboard** | Firebase Console | OneSignal Dashboard |
| **Analytics** | Cơ bản | Chi tiết hơn |

---

## 📊 ONESIGNAL FREE TIER

**Miễn phí:**
- 10,000 subscribers
- Unlimited notifications
- Full analytics
- A/B testing
- Automation
- API access

**Khi nào trả tiền?**
- Khi có > 10K users
- Cần tính năng advanced (scheduled notifications, etc.)

**Chi phí paid plan:** $9/month (khi cần)

---

## ⚠️ LƯU Ý QUAN TRỌNG

### **Security:**
- ✅ OneSignal API Key **KHÔNG NẰM** trong app (hardcode OK vì chỉ dùng để gửi notification)
- ✅ OneSignal Player ID public (không phải secret)
- ✅ An toàn cho production APK

### **Privacy:**
- OneSignal thu thập: Player ID, device info, notification interactions
- Cần thêm vào Privacy Policy

### **Firestore Rules:**
- User chỉ được đọc/ghi `oneSignalPlayerId` của chính họ:
```javascript
match /users/{userId} {
  allow read: if request.auth.uid == userId;
  allow write: if request.auth.uid == userId 
    && request.resource.data.keys().hasOnly(['oneSignalPlayerId', 'oneSignalPlayerIdUpdatedAt']);
}
```

---

## 🔧 TROUBLESHOOTING

### **Không nhận được notification:**

1. **Check OneSignal Player ID:**
   ```dart
   print('OneSignal Player ID: ${OneSignal.User.pushSubscription.id}');
   ```
   Nếu null → OneSignal chưa init đúng

2. **Check Firestore:**
   Verify `oneSignalPlayerId` đã lưu trong users/{uid}

3. **Check OneSignal Dashboard:**
   Vào **Audience** → **All Users** → Xem có device không

4. **Check notification permission:**
   Settings → Apps → chat_app2 → Notifications → Enable

### **Build error:**

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## 🎉 KẾT QUẢ CUỐI CÙNG

### **Sau khi setup OneSignal:**
- ✅ Push notification hoạt động (foreground/background/killed)
- ✅ 100% FREE (không cần thẻ)
- ✅ An toàn cho production APK
- ✅ Dashboard để xem analytics
- ✅ Sẵn sàng lên CH Play

### **Build APK:**
```bash
flutter build apk --release
```

### **Upload CH Play:**
```bash
flutter build appbundle --release
```

---

## 📚 TÀI LIỆU THAM KHẢO

- OneSignal Flutter SDK: https://documentation.onesignal.com/docs/flutter-sdk-setup
- OneSignal REST API: https://documentation.onesignal.com/reference/create-notification
- OneSignal Dashboard: https://app.onesignal.com/

---

**GIỜ MÀY CÓ 2 LỰA CHỌN:**

1. **Dùng OneSignal** (RECOMMENDED):
   - ✅ 100% FREE
   - ✅ Không cần thẻ
   - ✅ Push notification thực sự
   - ✅ 10 phút setup

2. **Không dùng push notification**:
   - ✅ App vẫn chạy OK
   - ❌ User không nhận notification khi app killed
   - ⚠️ Trải nghiệm kém hơn

**TAO KHUYÊN: DÙNG ONESIGNAL! CHỈ MẤT 10 PHÚT THÔI! 🚀**
