# 🔥 HƯỚNG DẪN FIREBASE CLOUD MESSAGING (FCM) HTTP v1 API

## ⚠️ QUAN TRỌNG: Firebase đã ngừng hỗ trợ Legacy API!

**Firebase Cloud Messaging API (Legacy)** đã bị **deprecated** (ngừng hỗ trợ) và **không còn hiển thị Server Key** trong Firebase Console nữa.

✅ **Giải pháp mới**: Sử dụng **FCM HTTP v1 API** với **Service Account JSON**

---

## 📋 MỤC LỤC
1. [Tại sao phải dùng FCM v1 API?](#tại-sao-phải-dùng-fcm-v1-api)
2. [Lấy Service Account JSON từ Firebase Console](#lấy-service-account-json)
3. [Cấu hình trong Flutter App](#cấu-hình-trong-flutter-app)
4. [Test thông báo](#test-thông-báo)
5. [Troubleshooting](#troubleshooting)

---

## 🤔 Tại sao phải dùng FCM v1 API?

### ❌ Legacy API (Cũ - Đã ngừng hỗ trợ):
- Server Key **không còn hiển thị** trong Firebase Console
- Endpoint `https://fcm.googleapis.com/fcm/send` **bị đóng**
- **Không an toàn**: Server key dễ bị lộ trong code

### ✅ FCM v1 API (Mới - Hiện tại):
- Dùng **OAuth 2.0** với Service Account JSON
- **An toàn hơn**: Credentials quản lý bởi Google
- **Tính năng mới**: Hỗ trợ nhiều platform, analytics tốt hơn
- **Bắt buộc**: Firebase yêu cầu migrate trước **June 2024**

---

## 📥 Lấy Service Account JSON

### BƯỚC 1: Truy cập Firebase Console

1. Vào **Firebase Console**: [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Chọn project **"chat_app2"** (hoặc project của bạn)

### BƯỚC 2: Vào Service Accounts

3. Click vào **biểu tượng bánh răng ⚙️** (Project Settings) ở góc trên bên trái
4. Chọn tab **"Service accounts"**

### BƯỚC 3: Tạo Private Key

5. Trong phần **"Firebase Admin SDK"**, click nút **"Generate new private key"**
6. Một popup xuất hiện, click **"Generate key"** để xác nhận
7. File JSON sẽ được tải về máy tự động (tên file: `chat-app2-xxxxx-firebase-adminsdk-xxxxx.json`)

### BƯỚC 4: Đổi tên file

8. Đổi tên file vừa tải về thành: **`service-account.json`**
   - Ví dụ: `chat-app2-dc9ce-firebase-adminsdk-abc123.json` → `service-account.json`

### BƯỚC 5: Lưu Project ID

9. Mở file `service-account.json` và tìm trường **`project_id`**
   ```json
   {
     "type": "service_account",
     "project_id": "chat-app2-dc9ce",  ← LƯU GIÁ TRỊ NÀY!
     "private_key_id": "...",
     ...
   }
   ```

---

## ⚙️ Cấu hình trong Flutter App

### CÁCdefault 1: Hardcode Service Account JSON (Cho testing nhanh)

**⚠️ CẢNH BÁO**: Phương pháp này **KHÔNG AN TOÀN** cho production! Chỉ dùng để test!

1. Mở file: **`lib/services/fcm_v1_service.dart`**

2. Tìm method `_loadServiceAccountJson()` (khoảng dòng 60)

3. **Uncomment OPTION 2** và paste nội dung file `service-account.json` vào:

```dart
// OPTION 2: Hardcode JSON (for testing only - DELETE BEFORE PRODUCTION)
return {
  "type": "service_account",
  "project_id": "chat-app2-dc9ce",  // ← Thay bằng project_id của bạn
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@chat-app2-dc9ce.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx%40chat-app2-dc9ce.iam.gserviceaccount.com"
};
```

4. **Update Project ID** ở đầu file (dòng 20):

```dart
static const String _projectId = 'chat-app2-dc9ce'; // ← Thay bằng project_id của bạn
```

5. **Cài dependencies**:

```bash
cd /home/user/chat_app2
flutter pub get
```

6. **Test ngay**:

```bash
flutter run
```

---

### CÁCH 2: Load từ Assets (Recommended cho Development)

**⚠️ LƯU Ý**: File JSON vẫn nằm trong app bundle, **không hoàn toàn an toàn** cho production!

1. **Tạo thư mục assets**:

```bash
cd /home/user/chat_app2
mkdir -p assets
```

2. **Copy file JSON vào assets**:

```bash
cp /path/to/service-account.json assets/service-account.json
```

3. **Thêm vào pubspec.yaml**:

```yaml
flutter:
  assets:
    - assets/service-account.json
```

4. **Uncomment OPTION 1** trong `lib/services/fcm_v1_service.dart`:

```dart
// OPTION 1: Load from assets (recommended for development)
final String jsonString = await rootBundle.loadString('assets/service-account.json');
return jsonDecode(jsonString) as Map<String, dynamic>;
```

5. **Import rootBundle** ở đầu file:

```dart
import 'package:flutter/services.dart' show rootBundle;
```

6. **Update Project ID** (dòng 20):

```dart
static const String _projectId = 'chat-app2-dc9ce'; // ← Thay bằng project_id của bạn
```

7. **Cài dependencies và test**:

```bash
flutter pub get
flutter run
```

---

### CÁCH 3: Load từ Backend API (RECOMMENDED cho Production)

**✅ AN TOÀN NHẤT**: Service Account JSON **không nằm trong app**, chỉ lấy khi cần.

1. **Tạo backend API endpoint** (Node.js, Python, etc.)
   - Endpoint: `GET https://your-backend.com/api/fcm-credentials`
   - Response: Service Account JSON (với authentication)

2. **Uncomment OPTION 3** trong `lib/services/fcm_v1_service.dart`:

```dart
// OPTION 3: Load from backend API (RECOMMENDED for production)
final response = await http.get(
  Uri.parse('https://your-backend.com/api/fcm-credentials'),
  headers: {
    'Authorization': 'Bearer YOUR_AUTH_TOKEN',
  },
);
return jsonDecode(response.body) as Map<String, dynamic>;
```

3. **Update Project ID** (dòng 20)

4. **Test**:

```bash
flutter pub get
flutter run
```

---

## 🧪 Test Thông Báo

### Test Case 1: Gửi tin nhắn văn bản

**Thiết bị A** (Người gửi):
1. Mở app, đăng nhập
2. Vào chat với người dùng khác
3. Gửi tin nhắn: "Hello!"

**Thiết bị B** (Người nhận):
1. **KILL APP** (swipe app ra khỏi recent apps)
2. Đợi vài giây
3. **Kiểm tra notification**:
   - ✅ Có notification xuất hiện với tiêu đề = tên người gửi
   - ✅ Nội dung = "Hello!"
   - ✅ Có âm thanh
   - ✅ Tap vào notification → Mở đúng cuộc trò chuyện

### Test Case 2: Foreground (App đang mở)

**Thiết bị B**:
1. Mở app, **KHÔNG vào chat screen** (ở HomeScreen)
2. Thiết bị A gửi tin nhắn
3. **Kiểm tra**:
   - ✅ Có local notification xuất hiện (đầu màn hình)
   - ✅ Tap vào → Mở đúng chat

### Test Case 3: Background (App minimize)

**Thiết bị B**:
1. Mở app, nhấn **Home button** (app vào background)
2. Thiết bị A gửi tin nhắn
3. **Kiểm tra**:
   - ✅ Có notification trong system tray
   - ✅ Tap vào → Mở app và vào đúng chat

### Test Case 4: After Restart (Sau khi khởi động lại)

**Thiết bị B**:
1. **Tắt máy** và **bật lại**
2. **KHÔNG MỞ APP**
3. Thiết bị A gửi tin nhắn
4. **Kiểm tra**:
   - ✅ Có notification xuất hiện ngay
   - ✅ Tap vào → Mở app và vào đúng chat

---

## 🐛 Troubleshooting

### Lỗi 1: "Service Account JSON not configured"

**Log**:
```
⚠️ [FCM v1] Service Account JSON not configured!
💡 [FCM v1] See instructions in fcm_v1_service.dart
```

**Giải pháp**:
1. Kiểm tra file `lib/services/fcm_v1_service.dart`
2. Uncomment một trong 3 OPTIONS trong method `_loadServiceAccountJson()`
3. Nếu dùng OPTION 2 (hardcode), paste đầy đủ nội dung file JSON
4. Update `_projectId` ở đầu file

### Lỗi 2: "Failed to get access token"

**Log**:
```
❌ [FCM v1] Get access token error: ...
❌ [FCM v1] Failed to get access token
```

**Nguyên nhân**:
- Service Account JSON không đúng định dạng
- Thiếu quyền trong Firebase project

**Giải pháp**:
1. Kiểm tra file `service-account.json` có đúng định dạng không
2. Đảm bảo trường `private_key` có `\n` (newline characters)
   - Đúng: `"-----BEGIN PRIVATE KEY-----\nMIIEvQI...\n-----END PRIVATE KEY-----\n"`
   - Sai: `"-----BEGIN PRIVATE KEY----- MIIEvQI... -----END PRIVATE KEY-----"`
3. Kiểm tra `client_email` có quyền Firebase Admin trong Console

### Lỗi 3: "Failed to send notification" (Status 403)

**Log**:
```
❌ [FCM v1] Failed to send notification
Status: 403
Body: {"error": "Permission denied..."}
```

**Nguyên nhân**: Service Account chưa có quyền gửi notification

**Giải pháp**:
1. Vào Firebase Console
2. **IAM & Admin** → **Service Accounts**
3. Tìm service account: `firebase-adminsdk-xxxxx@chat-app2-dc9ce.iam.gserviceaccount.com`
4. Click **"Permissions"**
5. Thêm role: **"Firebase Cloud Messaging Admin"**

### Lỗi 4: "Failed to send notification" (Status 404)

**Log**:
```
Status: 404
Body: {"error": "Project not found..."}
```

**Nguyên nhân**: Project ID sai

**Giải pháp**:
1. Mở file `service-account.json`
2. Copy giá trị `project_id`
3. Paste vào `lib/services/fcm_v1_service.dart` (dòng 20):
   ```dart
   static const String _projectId = 'PASTE_HERE';
   ```

### Lỗi 5: Không nhận được notification khi app bị kill

**Kiểm tra**:
1. **Google Play Services có cài không?**
   ```bash
   adb shell pm list packages | grep google
   ```
   - Nếu không có → Cài Google Play Services

2. **Notification permission đã bật chưa?**
   - Vào **Settings** → **Apps** → **chat_app2** → **Notifications** → **Enable**

3. **Battery optimization đã tắt chưa?** (Với điện thoại Trung Quốc)
   - Vào **Settings** → **Battery** → **Battery optimization** → **chat_app2** → **Don't optimize**

4. **FCM Token có hợp lệ không?**
   - Kiểm tra log:
   ```
   🔑 [FCM] Token: fDxxx...
   ```
   - Nếu token = null → FCM chưa initialize đúng

### Lỗi 6: "Package googleapis_auth not found"

**Giải pháp**:
```bash
cd /home/user/chat_app2
flutter pub get
```

Nếu vẫn lỗi, kiểm tra `pubspec.yaml`:
```yaml
dependencies:
  googleapis_auth: ^1.6.0
```

### Lỗi 7: Build failed "Missing rootBundle import"

**Nếu dùng OPTION 1 (load from assets)**:

Thêm import ở đầu file `fcm_v1_service.dart`:
```dart
import 'package:flutter/services.dart' show rootBundle;
```

---

## 📊 So sánh Legacy API vs v1 API

| Tính năng | Legacy API (Cũ) | FCM v1 API (Mới) |
|-----------|-----------------|------------------|
| **Server Key** | ✅ Có (nhưng đã ẩn) | ❌ Không còn |
| **Authentication** | Server Key (plaintext) | OAuth 2.0 (Service Account) |
| **Security** | ⚠️ Kém (key dễ bị lộ) | ✅ Cao (OAuth 2.0) |
| **Endpoint** | `https://fcm.googleapis.com/fcm/send` | `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send` |
| **Support** | ❌ Deprecated (June 2024) | ✅ Hiện tại |
| **Tính năng** | Cơ bản | ✅ Đầy đủ (multicast, topics, analytics) |

---

## 🎯 Kết luận

### ✅ Ưu điểm FCM v1 API:
- **An toàn hơn**: OAuth 2.0 thay vì plaintext key
- **Tính năng mới**: Hỗ trợ multicast, topics, analytics
- **Bắt buộc**: Firebase yêu cầu migrate

### ⚠️ Nhược điểm:
- **Setup phức tạp hơn**: Cần Service Account JSON và OAuth 2.0
- **Latency cao hơn ~200ms**: Do phải get access token trước khi gửi

### 💡 Khuyến nghị:

**Cho Development/Testing**:
- Dùng **OPTION 2** (hardcode JSON) hoặc **OPTION 1** (assets)
- Nhanh, dễ test

**Cho Production**:
- Dùng **OPTION 3** (load from backend API)
- An toàn nhất, credentials không nằm trong app
- Hoặc dùng **Firebase Cloud Functions** (Blaze plan)

---

## 📚 Tài liệu tham khảo

- [Firebase FCM v1 API Documentation](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Service Account Authentication](https://cloud.google.com/iam/docs/service-accounts)
- [googleapis_auth package](https://pub.dev/packages/googleapis_auth)

---

## 🚀 Next Steps

1. ✅ **Lấy Service Account JSON** từ Firebase Console
2. ✅ **Chọn một trong 3 CÁCH** để configure
3. ✅ **Update Project ID** trong code
4. ✅ **Test trên 2 thiết bị** với 4 test cases
5. ✅ **Deploy to production** với OPTION 3 (backend API)

---

## ❓ FAQ

**Q: Tại sao không dùng Cloud Functions thay vì HTTP request từ Flutter?**

A: Cloud Functions **yêu cầu Blaze plan** ($$$). Giải pháp HTTP từ Flutter **miễn phí 100%** và phù hợp với app nhỏ (<10K users).

**Q: Có an toàn không khi hardcode Service Account JSON trong app?**

A: **KHÔNG AN TOÀN** cho production! Chỉ dùng để test. Với production, phải dùng backend API (OPTION 3).

**Q: FCM v1 API có gửi được khi app bị kill không?**

A: **CÓ!** FCM v1 API hoạt động giống Legacy API. Notification vẫn đến ngay cả khi app bị kill hoàn toàn.

**Q: Có cần chạy backend server 24/7 không?**

A: **KHÔNG!** FCM gọi trực tiếp từ Flutter app. Không cần backend server, trừ khi dùng OPTION 3 (load credentials từ API).

**Q: Chi phí là bao nhiêu?**

A: **$0 - MIỄN PHÍ HOÀN TOÀN!** FCM unlimited notifications với Spark plan (free).

---

**CHỈ CẦN 5 PHÚT LÀ XONG! 🚀**
