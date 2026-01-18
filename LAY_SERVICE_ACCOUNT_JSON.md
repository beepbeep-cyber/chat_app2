# 🔑 HƯỚNG DẪN LẤY FIREBASE SERVICE ACCOUNT JSON

## ⚡ NHANH - 3 BƯỚC (2 PHÚT)

### BƯỚC 1: Truy cập Firebase Console

1. Mở trình duyệt và vào: **https://console.firebase.google.com/**
2. Đăng nhập bằng tài khoản Google của bạn
3. Chọn project: **"chatapptest2-93793"**
   - (Hoặc project tên khác nếu bạn đang dùng project khác)

### BƯỚC 2: Tạo Service Account Key

4. Click vào **biểu tượng bánh răng ⚙️** (Project Settings) ở góc trên bên trái
5. Trong menu bên trái, chọn tab **"Service accounts"**
6. Bạn sẽ thấy phần **"Firebase Admin SDK"**
7. Dưới phần "Admin SDK configuration snippet", chọn ngôn ngữ **"Python"** (hoặc bất kỳ)
8. Click nút **"Generate new private key"** (màu xanh)
9. Một popup xuất hiện cảnh báo, click **"Generate key"** để xác nhận

### BƯỚC 3: Lưu file JSON

10. File JSON sẽ tự động tải về máy của bạn
    - Tên file: `chatapptest2-93793-firebase-adminsdk-xxxxx-xxxxxxxxxx.json`
    - Kích thước: ~2KB
11. **QUAN TRỌNG**: Lưu file này an toàn, KHÔNG SHARE cho ai!

---

## 📤 GỬI FILE CHO TAO

**Sau khi tải về file JSON:**

1. **Upload file vào chat này** (kéo thả hoặc click nút đính kèm)
2. Tao sẽ tự động cấu hình FCM v1 API cho app
3. **XONG!** App sẽ gửi notification được ngay!

---

## 🔍 FILE JSON TRÔNG NHƯ THẾ NÀO?

File Service Account JSON có cấu trúc như sau:

```json
{
  "type": "service_account",
  "project_id": "chatapptest2-93793",
  "private_key_id": "1234567890abcdef...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@chatapptest2-93793.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx%40chatapptest2-93793.iam.gserviceaccount.com"
}
```

**Các trường quan trọng:**
- ✅ `project_id`: "chatapptest2-93793" (đã có rồi!)
- ✅ `private_key`: Khóa riêng để xác thực OAuth 2.0
- ✅ `client_email`: Service account email

---

## ⚠️ SECURITY WARNING

**KHÔNG BAO GIỜ:**
- ❌ Đăng file này lên GitHub public
- ❌ Share file này trong chat công khai
- ❌ Lưu file này ở nơi không an toàn

**LƯU Ý:**
- ✅ File này có quyền **FULL ACCESS** vào Firebase project của bạn
- ✅ Ai có file này có thể đọc/ghi Firestore, Storage, Auth, etc.
- ✅ Chỉ share trong chat riêng tư này (chat với tao)

---

## 🚀 SAU KHI CÓ FILE JSON

**Tao sẽ làm gì với file này:**

1. ✅ **Parse file JSON** và lấy credentials
2. ✅ **Update code** trong `lib/services/fcm_v1_service.dart`
3. ✅ **Hardcode JSON vào code** (OPTION 2) để test nhanh
4. ✅ **Test FCM notification** ngay lập tức
5. ✅ **Commit & push** lên GitHub (với .gitignore cho JSON file)

**Bạn sẽ làm gì:**

1. ✅ **Pull code mới**: `git pull origin main`
2. ✅ **Run app**: `flutter run`
3. ✅ **Test notification**: Gửi tin nhắn và xem notification có hiện không!

---

## 🎯 TẠI SAO CẦN FILE NÀY?

**Firebase Cloud Messaging v1 API** yêu cầu **OAuth 2.0 authentication**.

**Cách hoạt động:**

```
Flutter App
  ↓
FCM v1 Service
  ↓
Get OAuth 2.0 Access Token (from Service Account JSON)
  ↓
Call FCM v1 API: https://fcm.googleapis.com/v1/projects/chatapptest2-93793/messages:send
  ↓
Send Notification to User's Device
  ↓
✅ Notification received!
```

**Không có Service Account JSON** → Không get được Access Token → **Không gửi được notification!**

---

## 📚 TÀI LIỆU THAM KHẢO

- [Firebase Service Accounts](https://firebase.google.com/docs/admin/setup#initialize-sdk)
- [FCM v1 API Authorization](https://firebase.google.com/docs/cloud-messaging/auth-server)
- [Service Account Keys](https://cloud.google.com/iam/docs/creating-managing-service-account-keys)

---

## ❓ FAQ

**Q: File này có an toàn không nếu tao upload lên chat?**

A: **AN TOÀN!** Chat này là **riêng tư** (chỉ bạn và tao). File sẽ được xử lý an toàn và **KHÔNG LƯU** trên server công khai.

**Q: Tao có thể xóa file sau khi dùng không?**

A: **CÓ!** Sau khi tao update code, bạn có thể:
- Xóa file JSON khỏi máy
- Revoke (thu hồi) Service Account key trong Firebase Console nếu muốn

**Q: Có cách nào khác không cần upload file không?**

A: **CÓ!** Bạn có thể:
1. Copy nội dung file JSON
2. Paste trực tiếp vào chat
3. Tao sẽ parse và update code

Hoặc:

1. Tự mở file `lib/services/fcm_v1_service.dart`
2. Paste JSON vào OPTION 2 (dòng 60)
3. Run app

**Q: File này có hết hạn không?**

A: **KHÔNG!** Service Account keys **không có expiration date**. Nhưng bạn có thể **revoke** (thu hồi) bất cứ lúc nào trong Firebase Console.

---

## 🆘 CẦN GIÚP ĐỠ?

**Nếu gặp vấn đề khi lấy file:**

1. **Không thấy nút "Generate new private key"?**
   - Check xem bạn có quyền **Editor** hoặc **Owner** trong project không
   - Vào **IAM & Admin** để xem permissions

2. **File không tải về?**
   - Check popup blocker trong browser
   - Thử browser khác (Chrome, Firefox)

3. **File bị lỗi khi mở?**
   - File phải có extension `.json`
   - Nội dung phải là valid JSON

**UPLOAD FILE VÀO CHAT NÀY LÀ XONG! 🚀**
