# 🧪 MANUAL TEST: Incoming Call System

## 📋 PREREQUISITE CHECKS

### 1️⃣ Check Firebase Console - Firestore Database
```
1. Go to: https://console.firebase.google.com/
2. Select your project
3. Navigate: Build → Firestore Database
4. Verify collection exists: "incomingCalls"
5. Check if you can see documents in real-time
```

### 2️⃣ Check User Authentication
```
Device A (Caller):
- Open app
- Login as User A
- Check logcat: Should see "✅ [IncomingCall] Listener started successfully"
- Note User A's UID

Device B (Callee):  
- Open app
- Login as User B
- Check logcat: Should see "✅ [IncomingCall] Listener started successfully"
- Note User B's UID
```

### 3️⃣ Check Network Connection
```
Both devices must have:
✅ Internet connection
✅ Firebase connection
✅ No firewall blocking Firestore
```

---

## 🔍 DEBUG STEP 1: Verify Listener is Running

**On Device B (Callee):**

Connect to ADB and run:
```bash
adb logcat | grep IncomingCall
```

Expected output when app starts:
```
🔄 [IncomingCall] Starting listener for user: [USER_B_UID]
✅ [IncomingCall] Listener started successfully
```

If you DON'T see this:
❌ **Problem:** Listener not initialized
📝 **Solution:** Check if HomeScreen is loaded and user is logged in

---

## 🔍 DEBUG STEP 2: Manual Firestore Test

**Test using Firebase Console:**

1. Open Firebase Console
2. Go to Firestore Database
3. Click "Start collection"
4. Collection ID: `incomingCalls`
5. Add document with these fields:

```javascript
{
  "calleeUid": "USER_B_UID_HERE",     // Replace with actual UID
  "callerUid": "USER_A_UID_HERE",     // Replace with actual UID
  "callerName": "Test Caller",
  "callerAvatar": "",
  "channelName": "test_channel_123",
  "chatRoomId": "test_room_123",
  "status": "calling",
  "timestamp": [Use server timestamp],
  "createdAt": "2025-01-18T10:00:00Z"
}
```

6. Click "Save"

**Expected on Device B:**
Within 1-2 seconds, you should see:
```
📊 [IncomingCall] Snapshot received: 1 documents
   DocChanges: 1
   Change type: DocumentChangeType.added
   Document ID: [AUTO_ID]
📞 [IncomingCall] NEW CALL DETECTED!
   Caller: Test Caller
   CallerUid: USER_A_UID_HERE
✅ [IncomingCall] Triggering onIncomingCall callback
📞 [HomeScreen] Incoming call callback triggered!
```

**And a dialog should appear!**

If NO dialog appears:
- Check logcat for errors
- Verify `onIncomingCall` callback is set
- Check if dialog is behind other UI

---

## 🔍 DEBUG STEP 3: Test Real Video Call Flow

**Step-by-step:**

### Device A (Caller):
```
1. Open chat with User B
2. Click Video Call button
3. Check logcat for:
   🔔 [VideoCall] Preparing to send call notification...
   📤 [IncomingCall] Sending call...
   ✅ [IncomingCall] Document created successfully!
   ✅ [VideoCall] Call notification sent successfully!
```

### Device B (Callee):
```
Within 1-2 seconds, check logcat for:
   📊 [IncomingCall] Snapshot received: 1 documents
   📞 [IncomingCall] NEW CALL DETECTED!
   ✅ [IncomingCall] Triggering onIncomingCall callback
   📞 [HomeScreen] Incoming call callback triggered!

And dialog should appear!
```

### If Dialog Appears:
```
Click "Trả lời"
Check logcat for:
   ✅ [HomeScreen] Call accepted, joining channel: [CHANNEL_NAME]
   ✅ [IncomingCall] Call accepted: [CALL_ID]

Video call screen should open!
```

---

## ❌ COMMON PROBLEMS & SOLUTIONS

### Problem 1: No logs at all
**Symptom:** No [IncomingCall] logs in logcat
**Cause:** Listener not started
**Solution:**
1. Check if user is logged in
2. Verify HomeScreen is loaded
3. Check _initializeIncomingCallListener() is called
4. Add breakpoint in startListening()

### Problem 2: Listener logs but no callback
**Symptom:** See "Listener started" but no "Snapshot received"
**Cause:** No matching documents or Firestore rules blocking
**Solution:**
1. Manually add document in Firebase Console
2. Check Firestore rules allow read
3. Verify calleeUid matches current user UID
4. Check status = 'calling'

### Problem 3: Callback triggered but no dialog
**Symptom:** See "Triggering onIncomingCall callback" but no UI
**Cause:** Dialog context issue or UI state problem
**Solution:**
1. Check if HomeScreen is mounted
2. Verify context is valid
3. Add try-catch in _showIncomingCallDialog
4. Check if dialog is behind other screens

### Problem 4: Document created but listener doesn't detect
**Symptom:** Document exists in Firestore but no snapshot event
**Cause:** Listener started AFTER document creation
**Solution:**
1. Ensure listener starts BEFORE call is made
2. Check timestamp - listener only detects NEW documents
3. Delete old documents and create new one
4. Restart app to reinitialize listener

### Problem 5: Call notification sent but wrong user receives
**Symptom:** Wrong user gets the call
**Cause:** calleeUid mismatch
**Solution:**
1. Verify calleeUid in document matches User B UID
2. Check if multiple users logged in on same device
3. Clear app data and re-login

---

## 🎯 EXPECTED DEBUG FLOW (Full Success)

### Device A (Caller):
```
User A clicks Video Call button
  ↓
🔔 [VideoCall] Preparing to send call notification...
   CalleeUid: [USER_B_UID]
   CallerName: User A
   ChannelName: chatroom_123_456
  ↓
📤 [IncomingCall] Sending call...
   From: [USER_A_UID]
   To: [USER_B_UID]
  ↓
✅ [IncomingCall] Document created successfully!
   CallId: abc123xyz
   Path: incomingCalls/abc123xyz
   Status: calling
  ↓
✅ [VideoCall] Call notification sent successfully!
   CallId: abc123xyz
```

### Device B (Callee):
```
(1-2 seconds later)
  ↓
📊 [IncomingCall] Snapshot received: 1 documents
   DocChanges: 1
  ↓
   Change type: DocumentChangeType.added
   Document ID: abc123xyz
  ↓
📞 [IncomingCall] NEW CALL DETECTED!
   Caller: User A
   CallerUid: [USER_A_UID]
   CallId: abc123xyz
   ChannelName: chatroom_123_456
  ↓
✅ [IncomingCall] Triggering onIncomingCall callback
  ↓
📞 [HomeScreen] Incoming call callback triggered!
   Caller: User A
   CallId: abc123xyz
  ↓
🎨 Dialog appears with:
   Title: "📹 Cuộc gọi video đến"
   Avatar: User A's avatar
   Text: "User A đang gọi video cho bạn..."
   Buttons: [Từ chối] [Trả lời]
```

### User B clicks "Trả lời":
```
✅ [HomeScreen] Call accepted, joining channel: chatroom_123_456
  ↓
✅ [IncomingCall] Call accepted: abc123xyz
  ↓
🎥 VideoCallScreen opens
  ↓
🎥 VideoCall: Local user joined channel
  ↓
🎥 VideoCall: Remote user [USER_A_UID] joined
  ↓
✅ VIDEO CALL CONNECTED!
```

---

## 🔧 FIRESTORE RULES CHECK

**Required rules for incomingCalls collection:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /incomingCalls/{callId} {
      // Allow users to create calls
      allow create: if request.auth != null;
      
      // Allow caller and callee to read
      allow read: if request.auth != null && 
        (resource.data.callerUid == request.auth.uid || 
         resource.data.calleeUid == request.auth.uid);
      
      // Allow caller and callee to update
      allow update: if request.auth != null && 
        (resource.data.callerUid == request.auth.uid || 
         resource.data.calleeUid == request.auth.uid);
      
      // Allow caller and callee to delete
      allow delete: if request.auth != null && 
        (resource.data.callerUid == request.auth.uid || 
         resource.data.calleeUid == request.auth.uid);
    }
  }
}
```

**To check current rules:**
1. Firebase Console → Firestore Database
2. Click "Rules" tab
3. Verify the rules above exist
4. Click "Publish" if modified

---

## 📊 ADB LOGCAT COMMANDS

**Filter for incoming call logs:**
```bash
adb logcat | grep -E "IncomingCall|VideoCall|HomeScreen.*call"
```

**Clear logcat and start fresh:**
```bash
adb logcat -c
adb logcat | grep IncomingCall
```

**Save logs to file:**
```bash
adb logcat | grep IncomingCall > incoming_call_logs.txt
```

---

## 🎯 FINAL CHECKLIST

Before testing, verify:

- [ ] Firebase project configured correctly
- [ ] Firestore Database created
- [ ] "incomingCalls" collection exists (or will be auto-created)
- [ ] Firestore rules allow read/write
- [ ] Both users logged in
- [ ] Both devices have internet
- [ ] HomeScreen loaded on Device B
- [ ] ADB connected to Device B for logs
- [ ] User A has User B in contacts/chat

---

## 💡 TIPS

1. **Always check logcat FIRST** - It tells you exactly what's happening
2. **Test with Firebase Console** - Manually create document to isolate issues
3. **One device at a time** - Focus on Device B (callee) receiving first
4. **Check timestamps** - Old documents won't trigger listener
5. **Restart app** - If listener seems stuck, restart Device B's app

---

## 🆘 STILL NOT WORKING?

If after all these tests it still doesn't work:

1. **Capture full logcat:**
   ```bash
   adb logcat > full_debug_log.txt
   ```
   
2. **Send these to developer:**
   - Full logcat from both devices
   - Screenshot of Firestore console showing document
   - Screenshot of Firestore rules
   - User UIDs of both users
   - App version and build number

3. **Temporary workaround:**
   - Use manual Firestore Console to simulate calls
   - This proves the system works
   - Issue is likely in VideoCallScreen integration

---

**Good luck! 🍀**
