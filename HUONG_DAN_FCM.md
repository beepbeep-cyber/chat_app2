# 🔥 Hướng Dẫn Cài Đặt FCM Push Notifications

## 📱 **HOÀN TOÀN MIỄN PHÍ - KHÔNG CẦN CLOUD FUNCTIONS!**

App chat này dùng **Firebase Cloud Messaging (FCM) REST API** để gửi thông báo đẩy trực tiếp từ Flutter, **không cần Cloud Functions** hay gói Firebase trả phí.

---

## ✅ **Tại Sao Dùng Cách Này?**

| Tính năng | Cloud Functions (Blaze Plan) | FCM HTTP Trực Tiếp (MIỄN PHÍ) |
|-----------|------------------------------|-------------------------------|
| Chi phí | Cần Blaze plan ($$$) | **100% MIỄN PHÍ** |
| Cài đặt | Phức tạp | **Đơn giản** |
| Mở rộng | Cao (1M+ users) | Tốt (1K-100K users) |
| Độ trễ | Thấp (~100ms) | Trung bình (~500ms) |
| Bảo mật | Cao | Trung bình (server key trong app) |

**Với 1K người dùng**: FCM HTTP trực tiếp là **hoàn hảo** và hoàn toàn **MIỄN PHÍ**! ✅

---

## 🚀 **Hướng Dẫn Cài Đặt (5 Phút)**

### **Bước 1: Lấy Firebase Server Key**

1. Vào **[Firebase Console](https://console.firebase.google.com/)**
2. Chọn project của mày (`chat_app2`)
3. Bấm **⚙️ Cài đặt dự án** (biểu tượng bánh răng góc trên bên trái)
4. Chuyển sang tab **Cloud Messaging**
5. Kéo xuống **Cloud Messaging API (Legacy)**
6. Tìm **Server key** (bắt đầu bằng `AAAA...`)
7. Bấm nút **📋 Sao chép**

**Vị trí trên Firebase Console**:
```
Firebase Console
  → Cài đặt dự án
    → Cloud Messaging
      → Cloud Messaging API (Legacy)
        → Server key: [SAO CHÉP CÁI NÀY]
```

**Ảnh minh họa**:
```
╔════════════════════════════════════════════════════╗
║  Cloud Messaging API (Legacy)                      ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║  Server key                                        ║
║  ┌──────────────────────────────────────────────┐ ║
║  │ AAAAxxxxxxx:APAxxxxxxxxxxxxxxxxxxxxxxxxxx... │ ║
║  └──────────────────────────────────────────────┘ ║
║                                      [📋 Sao chép] ║
║                                                    ║
╚════════════════════════════════════════════════════╝
```

---

### **Bước 2: Thêm Server Key Vào App**

1. Mở file: `lib/services/fcm_http_service.dart`
2. Tìm dòng 17:
   ```dart
   static const String _serverKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';
   ```
3. Thay `YOUR_FIREBASE_SERVER_KEY_HERE` bằng server key vừa sao chép:
   ```dart
   static const String _serverKey = 'AAAAxxxxxxx:APAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
   ```
4. **Lưu file** (Ctrl+S / Cmd+S)

**⚠️ Lưu ý bảo mật**: 
- Với app production, nên lưu server key an toàn hơn (không để trong code)
- Dùng biến môi trường hoặc backend riêng
- Với app nhỏ (<10K users), cách này chấp nhận được

---

### **Bước 3: Test Thông Báo**

1. Chạy app trên **2 thiết bị** (hoặc 1 thiết bị + 1 giả lập)
2. Đăng nhập bằng **2 tài khoản khác nhau** trên mỗi thiết bị
3. Gửi tin nhắn từ Thiết bị A
4. **Thiết bị B sẽ nhận thông báo** 🎉

**Hành vi mong đợi**:
- ✅ Thông báo hiện khi app đang chạy nền (background)
- ✅ Thông báo hiện khi app bị đóng hoàn toàn (killed)
- ✅ Thông báo hiện khi app đang mở (foreground - dạng local notification)
- ✅ Bấm vào thông báo sẽ mở đúng chat

---

## 🛠️ **Xử Lý Sự Cố**

### **Vấn đề: Không nhận được thông báo**

**Kiểm tra #1: FCM Token**
```dart
// Trong app, in ra FCM token
final fcmService = FCMService();
await fcmService.initialize();
print('FCM Token: ${fcmService.fcmToken}');
```
- Token phải bắt đầu bằng chữ/số (không null)
- Token được lưu trong Firestore: `users/{uid}/fcmToken`

**Kiểm tra #2: Server Key**
- Đảm bảo đã sao chép đúng **Server key** (không phải Project ID hay App ID)
- Server key phải bắt đầu bằng `AAAA`
- Kiểm tra không có khoảng trắng hay dấu ngoặc thừa

**Kiểm tra #3: Kết Nối Internet**
- Cả người gửi và người nhận đều phải có internet
- Kiểm tra Firebase Console > Cloud Messaging để xem trạng thái gửi

**Kiểm tra #4: Quyền Thông Báo Android**
- Vào: Cài đặt > Ứng dụng > App của mày > Thông báo
- Đảm bảo thông báo được **bật**

---

### **Vấn đề: Lỗi "Server key not configured"**

**Giải pháp**:
1. Kiểm tra file `fcm_http_service.dart` dòng 17
2. Đảm bảo server key **KHÔNG PHẢI** `YOUR_FIREBASE_SERVER_KEY_HERE`
3. Server key phải là Firebase server key thật (70+ ký tự)

---

### **Vấn đề: Thông báo hoạt động khi app mở nhưng không hoạt động khi đóng app**

**Giải pháp (Android)**:
1. Kiểm tra `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.firebase.messaging.default_notification_channel_id"
       android:value="high_importance_channel" />
   ```
2. Đảm bảo dòng này nằm trong tag `<application>`
3. Build lại app: `flutter clean && flutter run`

**Giải pháp (Điện thoại Trung Quốc - Xiaomi/Oppo/Vivo)**:
- Các điện thoại này tự động kill app rất mạnh
- Vào: Cài đặt > Pin > Tối ưu hóa pin
- Tìm app của mày → Chọn **Không tối ưu hóa**

---

## 📊 **Cách Hoạt Động**

```
User A gửi tin nhắn
    ↓
1. Lưu tin nhắn vào Firestore
    ↓
2. Lấy FCM token của User B từ Firestore
    ↓
3. Gọi FCM REST API trực tiếp (HTTP POST)
    {
      "to": "fcm_token_user_b",
      "notification": {
        "title": "User A",
        "body": "Xin chào!"
      }
    }
    ↓
4. Firebase gửi thông báo đến thiết bị User B
    ↓
5. User B nhận thông báo 🎉
```

**Không cần Cloud Functions!** Mọi thứ chạy từ phía client. 🚀

---

## 🔥 **QUAN TRỌNG: Thông Báo Vẫn Hoạt Động Khi App Bị KILL!**

### **❓ Tại sao vẫn hoạt động khi app đã đóng?**

FCM không chạy trong app của mày! FCM chạy trong **Google Play Services** - một dịch vụ hệ thống của Android:

```
App của mày (chat_app2)
    ├── Có thể bị đóng/kill ❌
    └── FCM chỉ để NHẬN thông báo

Google Play Services (Dịch vụ hệ thống)
    ├── LUÔN LUÔN chạy ngầm ✅
    ├── Không thể đóng (được bảo vệ bởi Android)
    └── Nhận thông báo từ Firebase servers
```

### **📱 Test Các Trường Hợp**

| Trạng thái App | Thông báo FCM | Khi bấm thông báo |
|----------------|---------------|-------------------|
| **Đang mở** (foreground) | ✅ Hiện local notification | Mở chat |
| **Chạy nền** (minimize) | ✅ Thông báo system tray | Mở chat |
| **Đã đóng** (swipe away) | ✅ Thông báo system tray | **Mở app** + mở chat |
| **Sau khi khởi động lại** | ✅ Thông báo system tray | Mở app + mở chat |
| **Force stop từ Settings** | ✅ Thông báo system tray | Mở app + mở chat |

**Kết luận**: Thông báo **LUÔN HOẠT ĐỘNG**, bất kể app có đang chạy hay không! ✅

---

## 🔒 **Cân Nhắc Về Bảo Mật**

### **Cho Development/App Nhỏ (<10K users)**
- ✅ Cách HTTP trực tiếp là **chấp nhận được**
- ✅ 100% MIỄN PHÍ
- ✅ Đơn giản để triển khai

### **Cho Production/App Lớn (>10K users)**
- ⚠️ Nên chuyển server key sang backend an toàn
- ⚠️ Dùng Firebase Admin SDK trên backend
- ⚠️ Triển khai rate limiting
- ⚠️ Dùng Cloud Functions (cần Blaze plan)

**Gợi ý của tao**: 
- Dùng HTTP trực tiếp cho **MVP và app nhỏ**
- Nâng cấp lên Cloud Functions khi có **doanh thu** hoặc **>10K users**

---

## 💡 **Tính Năng Nâng Cao (Tùy chọn)**

### **Gửi thông báo cho các hành động khác**

**Tin nhắn ảnh**:
```dart
// Sau khi upload ảnh, gửi thông báo
FCMHttpService.sendNotificationToUser(
  userId: recipientUid,
  title: senderName,
  body: '📷 Đã gửi một ảnh',
  data: {'type': 'image', 'chatRoomId': chatRoomId},
  imageUrl: imageUrl, // Tùy chọn: hiển thị ảnh trong thông báo
);
```

**Tin nhắn thoại**:
```dart
FCMHttpService.sendNotificationToUser(
  userId: recipientUid,
  title: senderName,
  body: '🎤 Đã gửi tin nhắn thoại',
  data: {'type': 'voice', 'chatRoomId': chatRoomId},
);
```

**Tin nhắn nhóm**:
```dart
// Gửi cho nhiều người dùng
await FCMHttpService.sendNotificationToMultipleUsers(
  userIds: ['user1', 'user2', 'user3'],
  title: groupName,
  body: '$senderName: $message',
  data: {'type': 'group', 'groupId': groupId},
);
```

**Cuộc gọi video**:
```dart
FCMHttpService.sendVideoCallNotification(
  recipientUserId: recipientUid,
  callerName: callerName,
  callerAvatar: callerAvatar,
  channelName: channelName,
  chatRoomId: chatRoomId,
);
```

---

## 📈 **Giám Sát & Phân Tích**

### **Kiểm tra việc gửi thông báo**:
1. Vào **[Firebase Console](https://console.firebase.com/)**
2. Chuyển đến **Cloud Messaging** > **Báo cáo**
3. Xem:
   - Tổng số thông báo đã gửi
   - Tỷ lệ gửi thành công
   - Tỷ lệ mở thông báo
   - Tỷ lệ lỗi

### **Debug logs** (trong app):
```dart
// Bật chế độ debug
const bool kDebugMode = true;

// Kiểm tra logs
if (kDebugMode) {
  debugPrint('✅ [FCM HTTP] Đã gửi thông báo');
  debugPrint('❌ [FCM HTTP] Lỗi gửi: ...');
}
```

---

## 🎓 **Tài Liệu Tham Khảo**

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Pricing](https://firebase.google.com/pricing)

---

## ✅ **Tóm Tắt**

- ✅ **100% MIỄN PHÍ** cho số người dùng không giới hạn
- ✅ **Không cần Cloud Functions**
- ✅ **Cài đặt đơn giản** (5 phút)
- ✅ **Hoạt động tốt** cho app nhỏ-trung bình
- ✅ **Dễ nâng cấp** sau này nếu cần

**Chỉ cần thêm Firebase Server Key của mày là xong!** 🎉

---

## 🚀 **Các Bước Tiếp Theo**

### **1. Lấy Firebase Server Key** (2 phút)
- Vào Firebase Console
- Project Settings > Cloud Messaging
- Sao chép Server key

### **2. Thêm vào App** (1 phút)
- Mở `lib/services/fcm_http_service.dart`
- Dán server key vào dòng 17
- Lưu file

### **3. Test Trên 2 Thiết Bị** (2 phút)
- Chạy app trên 2 thiết bị
- Đăng nhập 2 tài khoản khác nhau
- Gửi tin nhắn
- Nhận thông báo ✅

### **4. XONG!** 🎉

**Tổng thời gian: 5 PHÚT**  
**Tổng chi phí: 0₫ (MIỄN PHÍ MÃI MÃI)** ✅

---

## 💬 **FAQ - Các Câu Hỏi Thường Gặp**

### **❓ FCM có miễn phí thật không?**
✅ **CÓ!** FCM hoàn toàn miễn phí, không giới hạn số thông báo hay người dùng.

### **❓ Có hoạt động khi app bị đóng không?**
✅ **CÓ!** Thông báo vẫn hoạt động ngay cả khi app bị kill hoàn toàn.

### **❓ Có cần Cloud Functions không?**
❌ **KHÔNG!** Giải pháp này gửi thông báo trực tiếp, không cần Cloud Functions hay Blaze plan.

### **❓ Server key có an toàn không?**
⚠️ Với app nhỏ (<10K users) thì OK. Với app lớn nên chuyển sang backend.

### **❓ Có hỗ trợ iOS không?**
✅ **CÓ!** Code hỗ trợ cả Android và iOS. Nhưng iOS cần thêm APNs certificate.

### **❓ Nếu muốn nâng cấp sau thì sao?**
✅ **DỄ DÀNG!** Chỉ cần chuyển sang Cloud Functions khi có doanh thu hoặc nhiều users.

---

## 🎉 **KẾT LUẬN**

**Giải pháp này hoàn hảo cho**:
- ✅ MVP và prototype
- ✅ App nhỏ (<10K users)
- ✅ Dự án cá nhân
- ✅ Startup giai đoạn đầu
- ✅ Người không có ngân sách

**CHỈ CẦN 5 PHÚT VÀ 0₫ ĐỂ CÓ PUSH NOTIFICATIONS HOÀN CHỈNH!** 🚀

---

**Có câu hỏi? Đọc lại phần Xử Lý Sự Cố ở trên hoặc check Firebase Console logs!**
