# ✅ GIẢI PHÁP VIDEO CALL KHÔNG CẦN FCM

## 🎯 VẤN ĐỀ
- FCM không hoạt động vì chưa có Firebase Blaze Plan (pay-as-you-go)
- Cần giải pháp MIỄN PHÍ để gửi incoming call notification

## 💡 GIẢI PHÁP: FIRESTORE REALTIME LISTENER

Thay vì FCM, sử dụng **Firestore** để lưu incoming calls và **listen realtime**!

### Cách hoạt động:
```
[User A] Nhấn video call
    ↓
[Firestore] Tạo document trong collection "incomingCalls"
    {
      calleeUid: "user_B_uid",
      callerName: "User A",
      channelName: "...",
      status: "calling"
    }
    ↓
[User B] Đang listen collection "incomingCalls" (filter: calleeUid == B)
    ↓
[User B] Nhận được realtime update
    ↓
[User B] Hiện dialog "Incoming call from User A"
    ↓
[User B] Nhấn Accept → Join Agora channel
    ↓
[Firestore] Update status = "accepted"
    ↓
[Both] Video call connected!
    ↓
[Firestore] Xóa document sau khi kết thúc
```

---

## 📁 FILES ĐÃ TẠO/SỬA

### 1. ✅ IncomingCallService (XONG)
**File**: `lib/services/incoming_call_service.dart`

**Chức năng**:
- `startListening()` - Bắt đầu listen incoming calls
- `stopListening()` - Dừng listen
- `sendCall()` - Gửi cuộc gọi (tạo document)
- `acceptCall()` - Accept cuộc gọi
- `rejectCall()` - Reject cuộc gọi
- `cancelCall()` - Hủy cuộc gọi (người gọi)
- `cleanupCall()` - Xóa document
- `cleanupOldCalls()` - Xóa calls cũ (>5 phút)

### 2. ✅ VideoCallScreen (ĐÃ SỬA)
**File**: `lib/screens/video_call_screen.dart`

**Thay đổi**:
- Import `IncomingCallService` thay vì `FCMService`
- Thêm `callId` parameter
- Thêm `_currentCallId` state
- Sửa `_sendCallNotification()` dùng `IncomingCallService.sendCall()`
- Sửa `_onCallEnd()` cleanup Firestore document

### 3. ⏳ HomeScreen (CẦN SỬA)
**File**: `lib/screens/chathome_screen.dart`

**Cần thêm**:
- Import `IncomingCallService` và `VideoCallScreen`
- Trong `initState()`: Start listening
- Trong `dispose()`: Stop listening
- Callback `onIncomingCall`: Show incoming call dialog
- Helper method `_showIncomingCallDialog()`: Dialog UI

---

## 🔧 CÁC BƯỚC CÒN LẠI

### BƯỚC 1: Sửa HomeScreen để listen incoming calls

Bạn có 2 lựa chọn:

**Option A: Tôi sửa code tự động (Khuyến nghị)**
- Tôi sẽ sửa `chathome_screen.dart`
- Thêm incoming call listener
- Tạo dialog incoming call đẹp

**Option B: Bạn test thủ công trước**
- Skip HomeScreen integration
- Test bằng cách manually tạo document trong Firestore Console
- Xem VideoCallScreen có gửi call được không

### BƯỚC 2: Test flow

**Device A (Người gọi):**
1. Vào chat với User B
2. Nhấn video call
3. Check Firestore Console → collection `incomingCalls` → Có document mới

**Device B (Người nhận):**
1. Đang ở HomeScreen
2. Kiểm tra logs: "📞 [IncomingCall] New call from: ..."
3. Dialog hiện ra với Accept/Reject buttons
4. Nhấn Accept → Join call

---

## 📊 FIRESTORE STRUCTURE

### Collection: `incomingCalls`

```
incomingCalls/{callId}:
  calleeUid: "user_B_uid"           // Người nhận cuộc gọi
  callerUid: "user_A_uid"           // Người gọi
  callerName: "John Doe"            // Tên người gọi
  callerAvatar: "https://..."       // Avatar người gọi
  channelName: "chatroom_123_..."   // Agora channel name
  chatRoomId: "chatroom_123"        // Chat room ID
  status: "calling"                 // calling | accepted | rejected | cancelled | missed
  timestamp: ServerTimestamp        // Thời gian tạo
  createdAt: "2025-01-14T..."       // ISO string
```

### Security Rules cần thêm:
```javascript
match /incomingCalls/{callId} {
  // Allow read for callee
  allow read: if request.auth.uid == resource.data.calleeUid 
              || request.auth.uid == resource.data.callerUid;
  
  // Allow create for authenticated users
  allow create: if request.auth != null;
  
  // Allow update/delete for caller or callee
  allow update, delete: if request.auth.uid == resource.data.calleeUid 
                        || request.auth.uid == resource.data.callerUid;
}
```

---

## ✅ LỢI ÍCH CỦA GIẢI PHÁP NÀY

1. ✅ **MIỄN PHÍ** - Không cần Blaze Plan
2. ✅ **Realtime** - Firestore snapshots rất nhanh (<1 giây)
3. ✅ **Reliable** - Không phụ thuộc FCM server
4. ✅ **Simple** - Code đơn giản, dễ debug
5. ✅ **Scalable** - Firestore có thể handle nhiều concurrent calls
6. ✅ **Cleanup** - Tự động xóa old calls

---

## ⚠️ LƯU Ý

### Giới hạn:
1. **App phải mở**: User B phải mở app (foreground/background) để nhận call
   - ❌ Nếu app bị kill hoàn toàn → Không nhận được
   - ✅ Nếu app ở background → Vẫn nhận được (listener còn active)

2. **Battery usage**: Listener realtime có thể tốn pin hơn FCM
   - Nhưng chấp nhận được cho MVP

3. **Firestore quota**: Free tier có giới hạn:
   - 50K reads/day
   - 20K writes/day
   - Với app nhỏ là đủ

### So sánh với FCM:
| Feature | FCM | Firestore Listener |
|---------|-----|-------------------|
| Nhận khi app killed | ✅ | ❌ |
| Nhận khi app background | ✅ | ✅ |
| Nhận khi app foreground | ✅ | ✅ |
| Chi phí | $$$ Blaze Plan | ✅ Free |
| Setup | Complex | Simple |
| Latency | <1s | <1s |
| Battery | Low | Medium |

---

## 🚀 TIẾP THEO

**BẠN MUỐN:**
1. **Option A**: Tôi tiếp tục sửa HomeScreen để hoàn thiện flow? (Khuyến nghị)
2. **Option B**: Build APK hiện tại và test thủ công xem gửi call có hoạt động không?

**Nếu chọn Option A**, tôi sẽ:
- Sửa `chathome_screen.dart`
- Thêm incoming call dialog đẹp với Accept/Reject
- Test flow hoàn chỉnh
- Build APK để bạn test

**Nếu chọn Option B**, bạn có thể:
- Build APK ngay
- Manually tạo document trong Firestore Console để test
- Xem logs để debug

**Bạn muốn chọn Option nào?**
