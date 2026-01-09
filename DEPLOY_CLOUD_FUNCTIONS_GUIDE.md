# 🚀 DEPLOY FIREBASE CLOUD FUNCTIONS - HƯỚNG DẪN

## 📋 **YÊU CẦU**

- ✅ Node.js 18+ đã cài đặt
- ✅ Firebase CLI đã cài đặt
- ✅ Firebase project đã tạo (chatapptest2-93793)
- ✅ Billing enabled (Blaze plan - free tier đủ dùng)

---

## 🔧 **BƯỚC 1: CÀI ĐẶT FIREBASE CLI**

### **Trên máy local:**

```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# Verify login
firebase projects:list
```

**Expected output:**
```
✔ Logged in successfully
✔ Project chatapptest2-93793 found
```

---

## 📦 **BƯỚC 2: SETUP FIREBASE PROJECT**

### **2.1. Initialize Firebase Functions (nếu chưa)**

```bash
cd /path/to/chat_app2

# Initialize Firebase (chọn Functions)
firebase init functions

# Select options:
# ? Select project: chatapptest2-93793
# ? Language: JavaScript
# ? Use ESLint: Yes
# ? Install dependencies: Yes
```

### **2.2. Cấu trúc thư mục:**

```
chat_app2/
├── firebase_functions/
│   ├── index.js         # Cloud Functions code (ĐÃ TẠO)
│   ├── package.json     # Dependencies (ĐÃ TẠO)
│   └── node_modules/    # (sẽ được tạo khi install)
├── firebase.json        # Firebase config
└── .firebaserc          # Firebase project config
```

---

## 🚀 **BƯỚC 3: DEPLOY CLOUD FUNCTIONS**

### **3.1. Cài đặt dependencies:**

```bash
cd firebase_functions
npm install
```

**Expected output:**
```
added 500+ packages
✔ Dependencies installed successfully
```

### **3.2. Deploy functions:**

```bash
cd ..  # Quay về root của project
firebase deploy --only functions
```

**Expected output:**
```
=== Deploying to 'chatapptest2-93793'...

i  deploying functions
✔  functions: Finished running predeploy script.
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (50.2 KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 18 function sendNotification(us-central1)...
i  functions: creating Node.js 18 function retryFailedNotifications(us-central1)...
i  functions: creating Node.js 18 function cleanupOldNotifications(us-central1)...
i  functions: creating Node.js 18 function sendTopicNotification(us-central1)...

✔  Deploy complete!

Functions:
  sendNotification: https://us-central1-chatapptest2-93793.cloudfunctions.net/sendNotification
  retryFailedNotifications: https://us-central1-chatapptest2-93793.cloudfunctions.net/retryFailedNotifications
  cleanupOldNotifications: https://us-central1-chatapptest2-93793.cloudfunctions.net/cleanupOldNotifications
  sendTopicNotification: https://us-central1-chatapptest2-93793.cloudfunctions.net/sendTopicNotification
```

---

## 🧪 **BƯỚC 4: KIỂM TRA DEPLOYMENT**

### **4.1. Verify functions deployed:**

```bash
firebase functions:list
```

**Expected output:**
```
┌──────────────────────────────┬───────────────┬─────────┐
│ Function                     │ Trigger       │ Region  │
├──────────────────────────────┼───────────────┼─────────┤
│ sendNotification             │ Firestore     │ us-c1   │
│ retryFailedNotifications     │ Scheduled     │ us-c1   │
│ cleanupOldNotifications      │ Scheduled     │ us-c1   │
│ sendTopicNotification        │ HTTP          │ us-c1   │
└──────────────────────────────┴───────────────┴─────────┘
```

### **4.2. Check logs:**

```bash
firebase functions:log
```

---

## 🧪 **BƯỚC 5: TEST FUNCTIONS**

### **Test 1: Trigger sendNotification**

**Tạo test notification trong Firestore:**

```javascript
// Vào Firebase Console → Firestore
// Tạo document mới trong collection 'notifications':

{
  "token": "fA1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8s9T0u1V2w3X4y5Z6",
  "title": "Test Notification",
  "body": "This is a test message from Cloud Function",
  "data": {
    "type": "chat",
    "chatRoomId": "test_chat_123"
  },
  "receiverId": "user_123",
  "senderId": "user_456",
  "createdAt": [Server timestamp],
  "sent": false
}
```

**Check logs sau 10 giây:**

```bash
firebase functions:log --only sendNotification
```

**Expected logs:**
```
📨 [FCM] Processing notification abc123
📨 [FCM] Receiver: user_123
📨 [FCM] Sender: user_456
📤 [FCM] Sending notification...
✅ [FCM] Sent successfully: projects/chatapptest2-93793/messages/0:1234567890
```

**Check Firestore document:**
```javascript
{
  "sent": true,  // ← Changed to true
  "sentAt": [Timestamp],
  "messageId": "projects/chatapptest2-93793/messages/0:1234567890"
}
```

---

## 💰 **CHI PHÍ**

### **Free Tier (Blaze Plan):**
- **Cloud Functions invocations**: 2,000,000/month free
- **Outbound networking**: 5GB/month free
- **CPU time**: 400,000 GB-seconds/month free

### **Ước tính cho Chat App:**

**Scenario: 1000 users, 10 messages/user/day**

```
Total notifications/month: 1000 users × 10 msg × 30 days = 300,000
Function invocations: 300,000 (WELL UNDER free tier)
Cost: $0/month ✅
```

**Khi vượt free tier:**
- **Cloud Functions**: $0.40/million invocations
- **Example**: 5 million invocations = $2/month

---

## 🔍 **MONITORING**

### **View logs realtime:**

```bash
# All functions
firebase functions:log

# Specific function
firebase functions:log --only sendNotification

# Tail logs (follow)
firebase functions:log --only sendNotification -n 50
```

### **Firebase Console:**

1. Vào Firebase Console
2. Build → Functions
3. Click vào function name
4. View logs, metrics, execution history

---

## 🚨 **TROUBLESHOOTING**

### **Issue 1: Deploy failed - Billing not enabled**

**Error:**
```
Cloud Functions deployment requires the pay-as-you-go (Blaze) billing plan.
```

**Fix:**
1. Vào Firebase Console
2. Upgrade to Blaze plan (free tier vẫn miễn phí)
3. Thêm payment method
4. Deploy lại

---

### **Issue 2: Functions not triggering**

**Check:**
```bash
# Verify function deployed
firebase functions:list

# Check logs for errors
firebase functions:log --only sendNotification

# Test manually via Firestore
# Tạo document mới trong collection 'notifications'
```

---

### **Issue 3: Invalid FCM token**

**Logs:**
```
❌ [FCM] Error: messaging/invalid-registration-token
```

**Fix:**
- Token đã expired hoặc invalid
- Function tự động xóa token khỏi user document
- User cần reopen app để get token mới

---

## 📊 **MONITORING DASHBOARD**

### **Create custom dashboard:**

**Metrics to track:**
- Notifications sent/hour
- Success rate
- Failed notifications
- Retry count
- Average processing time

**Query Firestore:**
```javascript
// Sent today
db.collection('notifications')
  .where('sent', '==', true)
  .where('sentAt', '>=', startOfDay)
  .get()

// Failed notifications
db.collection('notifications')
  .where('sent', '==', false)
  .where('error', '!=', null)
  .get()
```

---

## ✅ **POST-DEPLOYMENT CHECKLIST**

- [ ] Functions deployed successfully
- [ ] Test notification sent và received
- [ ] Logs showing successful sends
- [ ] Firestore documents updated correctly
- [ ] Invalid tokens removed automatically
- [ ] Retry mechanism working
- [ ] Cleanup running daily
- [ ] Monitoring setup

---

## 🎯 **NEXT STEPS**

### **1. Test trong Flutter app:**

```dart
// Send test notification
await NotificationHelper.sendMessageNotification(
  receiverId: 'other_user_uid',
  senderName: 'Test User',
  message: 'Hello from Cloud Function!',
  chatRoomId: 'test_chat',
);
```

### **2. Monitor for 24 hours:**
- Check success rate
- Monitor failed notifications
- Verify retry mechanism

### **3. Production ready:**
- [ ] All tests passing
- [ ] Error rate < 1%
- [ ] Monitoring alerts setup
- [ ] Documentation complete

---

## 📞 **HỖ TRỢ**

**Nếu gặp vấn đề:**

1. Check logs: `firebase functions:log`
2. Verify billing enabled
3. Check Firestore rules
4. Test with manual document creation
5. Contact Firebase support

**Useful commands:**
```bash
# Delete all functions
firebase functions:delete sendNotification
firebase functions:delete retryFailedNotifications
firebase functions:delete cleanupOldNotifications
firebase functions:delete sendTopicNotification

# Redeploy all
firebase deploy --only functions --force

# Deploy specific function
firebase deploy --only functions:sendNotification
```

---

## 🎉 **SUMMARY**

✅ **Cloud Functions sẽ:**
- Tự động gửi notifications khi có document mới trong `notifications` collection
- Retry failed notifications mỗi 5 phút
- Cleanup notifications cũ hơn 30 ngày
- Remove invalid FCM tokens tự động
- Support topic notifications

✅ **Cost**: $0/month cho <2M notifications (free tier)

✅ **Ready for production** sau khi test thành công!

---

**Bạn đã sẵn sàng deploy chưa?** 🚀
