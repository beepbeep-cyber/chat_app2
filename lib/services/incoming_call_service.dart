import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service để xử lý incoming video calls mà KHÔNG CẦN FCM
/// Sử dụng Firestore realtime listener để phát hiện cuộc gọi đến
class IncomingCallService {
  static final IncomingCallService _instance = IncomingCallService._internal();
  factory IncomingCallService() => _instance;
  IncomingCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<QuerySnapshot>? _callSubscription;
  Function(Map<String, dynamic> callData)? onIncomingCall;

  /// Bắt đầu listen incoming calls
  void startListening() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] No user logged in');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🔄 [IncomingCall] Starting listener for user: ${currentUser.uid}');
    }

    // Listen cho incoming calls của user hiện tại
    // CRITICAL: Only listen for calls WHERE I am the CALLEE (not caller!)
    _callSubscription = _firestore
        .collection('incomingCalls')
        .where('calleeUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen(
      (snapshot) {
        if (kDebugMode) {
          debugPrint('📊 [IncomingCall] Snapshot received: ${snapshot.docs.length} documents');
          debugPrint('   DocChanges: ${snapshot.docChanges.length}');
        }
        
        for (var doc in snapshot.docChanges) {
          if (kDebugMode) {
            debugPrint('   Change type: ${doc.type}');
            debugPrint('   Document ID: ${doc.doc.id}');
          }
          
          if (doc.type == DocumentChangeType.added) {
            // Có cuộc gọi mới đến!
            final callData = doc.doc.data() as Map<String, dynamic>;
            final callerUid = callData['callerUid'] as String?;
            
            // CRITICAL: Double-check that I am NOT the caller!
            // This prevents caller from receiving their own call notification
            if (callerUid == currentUser.uid) {
              if (kDebugMode) {
                debugPrint('⚠️ [IncomingCall] Ignoring own call - I am the caller!');
              }
              continue; // Skip this document
            }
            
            callData['callId'] = doc.doc.id; // Thêm callId để cleanup sau
            
            if (kDebugMode) {
              debugPrint('📞 [IncomingCall] NEW CALL DETECTED!');
              debugPrint('   Caller: ${callData['callerName']}');
              debugPrint('   CallerUid: $callerUid');
              debugPrint('   CalleeUid: ${callData['calleeUid']}');
              debugPrint('   CallId: ${doc.doc.id}');
              debugPrint('   ChannelName: ${callData['channelName']}');
            }
            
            // Trigger callback để show dialog
            if (onIncomingCall != null) {
              if (kDebugMode) {
                debugPrint('✅ [IncomingCall] Triggering onIncomingCall callback');
              }
              onIncomingCall!(callData);
            } else {
              if (kDebugMode) {
                debugPrint('❌ [IncomingCall] onIncomingCall callback is NULL!');
              }
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ [IncomingCall] Listener error: $error');
        }
      },
      onDone: () {
        if (kDebugMode) {
          debugPrint('⏹️ [IncomingCall] Listener closed');
        }
      },
    );

    if (kDebugMode) {
      debugPrint('✅ [IncomingCall] Listener started successfully');
    }
  }

  /// Dừng listen
  void stopListening() {
    _callSubscription?.cancel();
    _callSubscription = null;
    if (kDebugMode) {
      debugPrint('⏹️ [IncomingCall] Stopped listening');
    }
  }

  /// Gửi cuộc gọi (tạo document trong Firestore)
  static Future<String?> sendCall({
    required String calleeUid,
    required String callerName,
    required String channelName,
    String? callerAvatar,
    String? chatRoomId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('❌ [IncomingCall] sendCall: No user logged in');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('📤 [IncomingCall] Sending call...');
        debugPrint('   From: ${currentUser.uid}');
        debugPrint('   To: $calleeUid');
        debugPrint('   CallerName: $callerName');
        debugPrint('   ChannelName: $channelName');
      }

      // Tạo document trong collection "incomingCalls"
      final docRef = await FirebaseFirestore.instance
          .collection('incomingCalls')
          .add({
        'calleeUid': calleeUid,
        'callerUid': currentUser.uid,
        'callerName': callerName,
        'callerAvatar': callerAvatar ?? '',
        'channelName': channelName,
        'chatRoomId': chatRoomId ?? '',
        'status': 'calling', // calling, accepted, rejected, cancelled, missed
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('✅ [IncomingCall] Document created successfully!');
        debugPrint('   CallId: ${docRef.id}');
        debugPrint('   Path: incomingCalls/${docRef.id}');
        debugPrint('   Status: calling');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] Send call error: $e');
        debugPrint('   Stack: ${StackTrace.current}');
      }
      return null;
    }
  }

  /// Accept cuộc gọi (update status)
  static Future<void> acceptCall(String callId) async {
    try {
      await FirebaseFirestore.instance
          .collection('incomingCalls')
          .doc(callId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ [IncomingCall] Call accepted: $callId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] Accept call error: $e');
      }
    }
  }

  /// Reject cuộc gọi
  static Future<void> rejectCall(String callId) async {
    try {
      await FirebaseFirestore.instance
          .collection('incomingCalls')
          .doc(callId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ [IncomingCall] Call rejected: $callId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] Reject call error: $e');
      }
    }
  }

  /// Cancel cuộc gọi (người gọi hủy)
  static Future<void> cancelCall(String callId) async {
    try {
      await FirebaseFirestore.instance
          .collection('incomingCalls')
          .doc(callId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ [IncomingCall] Call cancelled: $callId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] Cancel call error: $e');
      }
    }
  }

  /// Cleanup call document (xóa sau khi kết thúc)
  static Future<void> cleanupCall(String callId) async {
    try {
      await FirebaseFirestore.instance
          .collection('incomingCalls')
          .doc(callId)
          .delete();
      
      if (kDebugMode) {
        debugPrint('✅ [IncomingCall] Call cleaned up: $callId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] Cleanup error: $e');
      }
    }
  }

  /// Cleanup old calls (>5 phút)
  static Future<void> cleanupOldCalls() async {
    try {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      
      final oldCalls = await FirebaseFirestore.instance
          .collection('incomingCalls')
          .where('timestamp', isLessThan: fiveMinutesAgo)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in oldCalls.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (kDebugMode) {
        debugPrint('🧹 [IncomingCall] Cleaned up ${oldCalls.docs.length} old calls');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [IncomingCall] Cleanup old calls error: $e');
      }
    }
  }
}
