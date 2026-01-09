# 🚀 HƯỚNG DẪN DEPLOY CLOUD FUNCTIONS - THỰC HIỆN NGAY

## ⚠️ **LƯU Ý QUAN TRỌNG**
Deploy phải thực hiện từ **máy local của bạn** (không phải sandbox) vì cần Firebase authentication.

---

## 📋 **BƯỚC 1: CHUẨN BỊ TRÊN MÁY LOCAL**

### **1.1. Kiểm tra Node.js**
```bash
node --version
# Cần: v18 trở lên
# Nếu chưa có: tải từ https://nodejs.org/
```

### **1.2. Cài đặt Firebase CLI**
```bash
npm install -g firebase-tools

# Verify installation
firebase --version
```

### **1.3. Clone repository**
```bash
# Clone project từ GitHub
git clone https://github.com/beepbeep-cyber/chat_app2.git
cd chat_app2
```

---

## 🔐 **BƯỚC 2: LOGIN VÀO FIREBASE**

```bash
# Login to Firebase
firebase login

# Browser sẽ mở → Chọn Google account của bạn
# ✅ Allow Firebase CLI access
```

**Expected output:**
```
✔  Success! Logged in as your-email@gmail.com
```

**Verify login:**
```bash
firebase projects:list
```

**Expected output:**
```
✔ Preparing the list of your Firebase projects
┌──────────────────────┬────────────────────────┬────────────────┬──────────────────────┐
│ Project Display Name │ Project ID             │ Project Number │ Resource Location ID │
├──────────────────────┼────────────────────────┼────────────────┼──────────────────────┤
│ chatapptest2         │ chatapptest2-93793     │ ...            │ us-central           │
└──────────────────────┴────────────────────────┴────────────────┴──────────────────────┘
```

---

## 🔧 **BƯỚC 3: SETUP FIREBASE PROJECT**

### **3.1. Initialize Firebase (nếu chưa có firebase.json)**

**Kiểm tra xem có file `firebase.json` chưa:**
```bash
ls -la firebase.json
```

**Nếu CHƯA CÓ → Initialize:**
```bash
firebase init functions

# Chọn:
? Select project: chatapptest2-93793
? Language: JavaScript  
? Use ESLint: Yes
? Install dependencies: Yes
```

**Nếu ĐÃ CÓ → Skip bước này**

### **3.2. Verify project setup**
```bash
cat .firebaserc
```

**Expected content:**
```json
{
  "projects": {
    "default": "chatapptest2-93793"
  }
}
```

**Nếu sai project ID → Fix:**
```bash
firebase use chatapptest2-93793
```

---

## 📦 **BƯỚC 4: CÀI ĐẶT DEPENDENCIES**

```bash
cd firebase_functions
npm install
```

**Expected output:**
```
added 500+ packages in 30s
✔ Dependencies installed successfully
```

**Verify installation:**
```bash
ls -la node_modules/ | head -10
```

---

## 🚀 **BƯỚC 5: DEPLOY FUNCTIONS**

### **5.1. Deploy tất cả functions:**
```bash
# Quay về root directory
cd ..

# Deploy
firebase deploy --only functions
```

**⏰ Thời gian: ~3-5 phút**

**Expected output:**
```
=== Deploying to 'chatapptest2-93793'...

i  deploying functions
✔  functions: Finished running predeploy script.
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: preparing codebase default for deployment
i  functions: preparing firebase_functions directory for uploading...
i  functions: packaged firebase_functions (50.2 KB) for uploading
✔  functions: firebase_functions folder uploaded successfully

The following functions will be deployed:
  sendNotification(us-central1)
  retryFailedNotifications(us-central1)
  cleanupOldNotifications(us-central1)
  sendTopicNotification(us-central1)

i  functions: creating Node.js 18 function sendNotification(us-central1)...
i  functions: creating Node.js 18 function retryFailedNotifications(us-central1)...
i  functions: creating Node.js 18 function cleanupOldNotifications(us-central1)...
i  functions: creating Node.js 18 function sendTopicNotification(us-central1)...
✔  functions[sendNotification(us-central1)] Successful create operation.
✔  functions[retryFailedNotifications(us-central1)] Successful create operation.
✔  functions[cleanupOldNotifications(us-central1)] Successful create operation.
✔  functions[sendTopicNotification(us-central1)] Successful create operation.

✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/chatapptest2-93793/overview
```

---

## ✅ **BƯỚC 6: VERIFY DEPLOYMENT**

### **6.1. List deployed functions:**
```bash
firebase functions:list
```

**Expected output:**
```
┌──────────────────────────────┬───────────────┬───────────┐
│ Function                     │ Trigger       │ Region    │
├──────────────────────────────┼───────────────┼───────────┤
│ sendNotification             │ Firestore     │ us-c1     │
│ retryFailedNotifications     │ Scheduled     │ us-c1     │
│ cleanupOldNotifications      │ Scheduled     │ us-c1     │
│ sendTopicNotification        │ HTTP          │ us-c1     │
└──────────────────────────────┴───────────────┴───────────┘

4 function(s) deployed successfully
```

### **6.2. Check Firebase Console:**

Vào: **https://console.firebase.google.com/project/chatapptest2-93793/functions**

Should see:
- ✅ `sendNotification` (Firestore trigger)
- ✅ `retryFailedNotifications` (Scheduled)
- ✅ `cleanupOldNotifications` (Scheduled)
- ✅ `sendTopicNotification` (HTTP)

---

## 🧪 **BƯỚC 7: TEST FUNCTIONS**

### **Test 1: Manual Firestore Trigger**

**Vào Firebase Console:**
https://console.firebase.google.com/project/chatapptest2-93793/firestore/databases/-default-/data/~2F

**Tạo document mới:**

**Collection:** `notifications`

**Click "Add document"**

**Auto-generate ID** (để trống)

**Fields:**
```
token (string): "fA1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8s9T0u1V2w3X4y5Z6"
title (string): "Test Notification"
body (string): "Testing Cloud Function - Please receive this!"
data (map):
  - type (string): "chat"
  - chatRoomId (string): "test_123"
receiverId (string): "test_user"
senderId (string): "system"
createdAt (timestamp): [Click "Use server timestamp"]
sent (boolean): false
```

**Click "Save"**

### **Check results (sau 10 giây):**

**1. View document again:**
```
✅ sent: true (changed from false)
✅ sentAt: [Timestamp added]
✅ messageId: "projects/chatapptest2-93793/messages/xyz" (added)
```

**2. Check logs:**
```bash
firebase functions:log --only sendNotification -n 20
```

**Expected logs:**
```
📨 [FCM] Processing notification abc123
📨 [FCM] Receiver: test_user
📨 [FCM] Sender: system
📤 [FCM] Sending notification...
✅ [FCM] Sent successfully: projects/.../messages/xyz
```

---

## 🚨 **TROUBLESHOOTING**

### **Issue 1: Deploy failed - Billing not enabled**

**Error:**
```
HTTP Error: 403, Cloud Functions deployment requires billing account
```

**Fix:**
1. Vào Firebase Console
2. Click "Upgrade" → Chọn "Blaze Plan"
3. Thêm payment method (credit card)
4. ✅ Free tier vẫn MIỄN PHÍ (2M invocations/month)
5. Deploy lại

---

### **Issue 2: Permission denied**

**Error:**
```
Error: HTTP Error: 403, Missing necessary permission
```

**Fix:**
```bash
# Verify project
firebase use

# Switch project if needed
firebase use chatapptest2-93793

# Login lại
firebase logout
firebase login
```

---

### **Issue 3: Functions not triggering**

**Check:**
1. Verify function deployed: `firebase functions:list`
2. Check logs: `firebase functions:log`
3. Verify Firestore document created correctly
4. Check Firebase Console → Functions → Logs

---

### **Issue 4: "Cannot find module"**

**Fix:**
```bash
cd firebase_functions
rm -rf node_modules package-lock.json
npm install
cd ..
firebase deploy --only functions
```

---

## 📊 **MONITORING**

### **View logs realtime:**
```bash
# All functions
firebase functions:log

# Specific function
firebase functions:log --only sendNotification

# Follow/tail logs
firebase functions:log --only sendNotification -n 50
```

### **Firebase Console:**
https://console.firebase.google.com/project/chatapptest2-93793/functions/logs

---

## ✅ **SUCCESS CHECKLIST**

- [ ] Firebase CLI installed
- [ ] Logged in to Firebase
- [ ] Project verified (chatapptest2-93793)
- [ ] Dependencies installed
- [ ] Functions deployed successfully
- [ ] All 4 functions showing in Console
- [ ] Test notification sent successfully
- [ ] Document updated (sent: true)
- [ ] Logs showing success messages

---

## 🎉 **KẾT QUẢ MONG ĐỢI**

### **Sau khi deploy thành công:**

✅ **Functions URLs:**
```
sendNotification: 
  https://us-central1-chatapptest2-93793.cloudfunctions.net/sendNotification

retryFailedNotifications:
  https://us-central1-chatapptest2-93793.cloudfunctions.net/retryFailedNotifications

cleanupOldNotifications:
  https://us-central1-chatapptest2-93793.cloudfunctions.net/cleanupOldNotifications

sendTopicNotification:
  https://us-central1-chatapptest2-93793.cloudfunctions.net/sendTopicNotification
```

✅ **Workflow:**
1. Flutter app tạo document trong `notifications` collection
2. Cloud Function `sendNotification` trigger tự động
3. FCM message được gửi đến device
4. Document được update: `sent: true`
5. User nhận notification! 📱

---

## 📞 **BẠN CẦN HỖ TRỢ?**

**Nếu gặp lỗi trong quá trình deploy:**
1. Copy error message đầy đủ
2. Chụp screenshot nếu có
3. Gửi cho tôi để troubleshoot

**Hoặc share logs:**
```bash
firebase functions:log > logs.txt
# Gửi file logs.txt cho tôi
```

---

## 🚀 **QUICK COMMANDS**

```bash
# Deploy workflow (copy & paste)
cd ~/chat_app2
git pull origin main
cd firebase_functions
npm install
cd ..
firebase use chatapptest2-93793
firebase deploy --only functions

# View logs
firebase functions:log --only sendNotification

# Redeploy specific function
firebase deploy --only functions:sendNotification

# Delete function
firebase functions:delete sendNotification
```

---

## 🎯 **SAU KHI DEPLOY XONG**

**Báo cho tôi biết:**
1. ✅ Deploy thành công
2. ✅ Test manual notification passed
3. ✅ Logs showing success

**Sau đó chúng ta sẽ:**
1. Test integration với Flutter app
2. Build APK và test on device
3. Monitor trong 24h để verify
4. Production ready! 🎉

---

**BẮT ĐẦU DEPLOY NGAY!** 🚀

```bash
# Copy toàn bộ workflow này:
cd ~/Downloads  # hoặc thư mục bạn muốn
git clone https://github.com/beepbeep-cyber/chat_app2.git
cd chat_app2
firebase login
firebase use chatapptest2-93793
cd firebase_functions
npm install
cd ..
firebase deploy --only functions
```

**Thời gian ước tính: 5-10 phút**

**Chúc bạn deploy thành công!** 🎉
