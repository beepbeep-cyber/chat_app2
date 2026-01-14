import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service để tự động xóa tin nhắn theo cài đặt của chatroom
class AutoDeleteService {
  static final AutoDeleteService _instance = AutoDeleteService._internal();
  factory AutoDeleteService() => _instance;
  AutoDeleteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Map để lưu trữ các timer đang chạy cho mỗi chatroom
  final Map<String, Timer> _activeTimers = {};
  
  // Map để lưu trữ các subscription đang lắng nghe
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  /// Khởi động service cho một chatroom
  /// Gọi khi user mở ChatScreen
  Future<void> startMonitoring(String chatRoomId) async {
    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Starting monitoring for chatroom: $chatRoomId'); }
    }

    // Hủy subscription cũ nếu có
    await _activeSubscriptions[chatRoomId]?.cancel();

    // Lắng nghe thay đổi cài đặt auto-delete của chatroom
    _activeSubscriptions[chatRoomId] = _firestore
        .collection('chatroom')
        .doc(chatRoomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final autoDeleteEnabled = data['autoDeleteEnabled'] ?? false;
        final autoDeleteDuration = data['autoDeleteDuration'] ?? 0;

        if (kDebugMode) {
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Settings changed - Enabled: $autoDeleteEnabled, Duration: $autoDeleteDuration mins'); }
        }

        if (autoDeleteEnabled && autoDeleteDuration > 0) {
          _startAutoDeleteTimer(chatRoomId, autoDeleteDuration);
        } else {
          _stopAutoDeleteTimer(chatRoomId);
        }
      }
    });
  }

  /// Dừng monitoring cho một chatroom
  /// Gọi khi user rời ChatScreen
  Future<void> stopMonitoring(String chatRoomId) async {
    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Stopping monitoring for chatroom: $chatRoomId'); }
    }
    
    await _activeSubscriptions[chatRoomId]?.cancel();
    _activeSubscriptions.remove(chatRoomId);
    _stopAutoDeleteTimer(chatRoomId);
  }

  /// Bắt đầu timer để xóa tin nhắn định kỳ
  void _startAutoDeleteTimer(String chatRoomId, int durationMinutes) {
    // Hủy timer cũ nếu có
    _activeTimers[chatRoomId]?.cancel();

    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Starting timer for $chatRoomId - Duration: $durationMinutes minutes'); }
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Will check every 30 seconds for messages older than $durationMinutes minutes'); }
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] 🔒 IMPORTANT: Only messages sent AFTER enabling auto-delete will be deleted!'); }
    }

    // 🔒 KHÔNG chạy ngay lập tức! Chỉ xóa tin nhắn MỚI sau khi enable
    // Loại bỏ dòng này: _deleteOldMessages(chatRoomId, durationMinutes);

    // Thiết lập timer chạy định kỳ mỗi 30 giây để kiểm tra và xóa
    _activeTimers[chatRoomId] = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _deleteOldMessages(chatRoomId, durationMinutes),
    );
  }

  /// Dừng timer
  void _stopAutoDeleteTimer(String chatRoomId) {
    _activeTimers[chatRoomId]?.cancel();
    _activeTimers.remove(chatRoomId);
    
    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Timer stopped for $chatRoomId'); }
    }
  }

  /// Xóa các tin nhắn cũ hơn thời gian quy định
  Future<void> _deleteOldMessages(String chatRoomId, int durationMinutes) async {
    try {
      // Tính thời điểm cutoff
      final cutoffTime = DateTime.now().subtract(Duration(minutes: durationMinutes));
      
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] ========================================'); }
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Checking chatroom: $chatRoomId'); }
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Current time: ${DateTime.now()}'); }
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Cutoff time: $cutoffTime'); }
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Delete messages older than $durationMinutes minutes'); }
      }

      // Query các tin nhắn cũ hơn cutoff time
      final oldMessages = await _firestore
          .collection('chatroom')
          .doc(chatRoomId)
          .collection('chats')
          .where('timeStamp', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      if (oldMessages.docs.isEmpty) {
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete] No old messages found to delete'); }
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete] ========================================'); }
        }
        return;
      }

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Found ${oldMessages.docs.length} messages to delete!'); }
        for (var doc in oldMessages.docs) {
          final data = doc.data();
          final msgTime = (data['timeStamp'] as Timestamp?)?.toDate();
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete]   - Message from $msgTime: "${(data['message'] ?? '').toString().substring(0, (data['message'] ?? '').toString().length > 30 ? 30 : (data['message'] ?? '').toString().length)}..."'); }
        }
      }

      // Batch delete để tối ưu performance
      WriteBatch batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in oldMessages.docs) {
        batch.delete(doc.reference);
        deleteCount++;
        
        // Firestore batch limit là 500, nên commit mỗi 450 documents
        if (deleteCount >= 450) {
          await batch.commit();
          if (kDebugMode) {
            if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Committed batch of $deleteCount deletes'); }
          }
          batch = _firestore.batch();
          deleteCount = 0;
        }
      }

      // Commit remaining
      if (deleteCount > 0) {
        await batch.commit();
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Committed final batch of $deleteCount deletes'); }
        }
      }

      if (kDebugMode) {
        if (kDebugMode) { debugPrint('✅ [AutoDelete] Successfully deleted ${oldMessages.docs.length} old messages'); }
      }

      // Cập nhật last message trong chatroom nếu cần
      await _updateLastMessage(chatRoomId);
      
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] ========================================'); }
      }

    } catch (e, stackTrace) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [AutoDelete] Error deleting messages: $e'); }
        if (kDebugMode) { debugPrint('❌ [AutoDelete] Stack trace: $stackTrace'); }
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] ========================================'); }
      }
    }
  }

  /// Cập nhật last message trong chatroom và chat history sau khi xóa
  Future<void> _updateLastMessage(String chatRoomId) async {
    try {
      // Lấy tin nhắn mới nhất còn lại
      final latestMessages = await _firestore
          .collection('chatroom')
          .doc(chatRoomId)
          .collection('chats')
          .orderBy('timeStamp', descending: true)
          .limit(1)
          .get();

      String newLastMessage = '';
      String newType = 'text';
      String newTime = '';

      if (latestMessages.docs.isNotEmpty) {
        final latestMessage = latestMessages.docs.first.data();
        newLastMessage = latestMessage['message'] ?? '';
        newType = latestMessage['type'] ?? 'text';
        newTime = latestMessage['time'] ?? '';
        
        await _firestore.collection('chatroom').doc(chatRoomId).update({
          'lastMessage': newLastMessage,
          'type': newType,
        });
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Updated last message to: "$newLastMessage"'); }
        }
      } else {
        // Không còn tin nhắn nào
        await _firestore.collection('chatroom').doc(chatRoomId).update({
          'lastMessage': '',
          'type': 'text',
        });
        if (kDebugMode) {
          if (kDebugMode) { debugPrint('🗑️ [AutoDelete] No messages left, cleared last message'); }
        }
      }
      
      // IMPORTANT: Also update chat history for all users to reflect in home screen
      await _updateChatHistoryForAllUsers(chatRoomId, newLastMessage, newType, newTime);
      
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [AutoDelete] Error updating last message: $e'); }
      }
    }
  }
  
  /// Update chat history for all users in the chatroom
  Future<void> _updateChatHistoryForAllUsers(String chatRoomId, String lastMessage, String type, String time) async {
    try {
      // Get chatroom info to find participants
      final chatroomDoc = await _firestore.collection('chatroom').doc(chatRoomId).get();
      if (!chatroomDoc.exists) return;
      
      final chatroomData = chatroomDoc.data()!;
      List<String> users = [];
      
      // Try to get users from 'users' field first
      if (chatroomData['users'] != null) {
        users = (chatroomData['users'] as List<dynamic>).map((e) => e.toString()).toList();
      } else {
        // Fallback: Try to extract users from chatRoomId (format: uid1_uid2)
        final parts = chatRoomId.split('_');
        if (parts.length >= 2) {
          users = [parts[0], parts[1]];
          
          // Save users to chatroom for future reference
          await _firestore.collection('chatroom').doc(chatRoomId).update({
            'users': users,
          });
          
          if (kDebugMode) {
            debugPrint('🗑️ [AutoDelete] Extracted users from chatRoomId: $users');
          }
        }
      }
      
      if (users.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ [AutoDelete] No users found for chatroom: $chatRoomId');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🗑️ [AutoDelete] Updating chat history for ${users.length} users: $users');
      }
      
      // Update chat history for each user
      for (final userId in users) {
        try {
          // First, find the other user's ID to use as the document ID in chatHistory
          final otherUserId = users.firstWhere((u) => u != userId, orElse: () => '');
          
          if (otherUserId.isEmpty) continue;
          
          final historyDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('chatHistory')
              .doc(otherUserId)
              .get();
          
          if (historyDoc.exists) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('chatHistory')
                .doc(otherUserId)
                .update({
              'lastMessage': lastMessage.isEmpty ? 'No messages' : lastMessage,
              'type': type,
              if (time.isNotEmpty) 'time': time,
            });
            
            if (kDebugMode) {
              debugPrint('🗑️ [AutoDelete] Updated chat history for user: $userId -> $otherUserId');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [AutoDelete] Failed to update history for user $userId: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AutoDelete] Error updating chat history: $e');
      }
    }
  }

  /// Xóa tất cả tin nhắn trong chatroom (manual delete all)
  /// IMPORTANT: This preserves auto-delete settings while only clearing messages
  Future<bool> deleteAllMessages(String chatRoomId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ [AutoDelete] Deleting ALL messages in chatroom: $chatRoomId');
      }

      // First, save current auto-delete settings BEFORE any changes
      final chatroomDoc = await _firestore.collection('chatroom').doc(chatRoomId).get();
      Map<String, dynamic>? savedSettings;
      
      if (chatroomDoc.exists) {
        final data = chatroomDoc.data()!;
        savedSettings = {
          'autoDeleteEnabled': data['autoDeleteEnabled'],
          'autoDeleteDuration': data['autoDeleteDuration'],
          'autoDeleteUpdatedBy': data['autoDeleteUpdatedBy'],
          'autoDeleteUpdatedAt': data['autoDeleteUpdatedAt'],
          'users': data['users'],
        };
        if (kDebugMode) {
          debugPrint('🗑️ [AutoDelete] Saved settings before delete: $savedSettings');
        }
      }

      final allMessages = await _firestore
          .collection('chatroom')
          .doc(chatRoomId)
          .collection('chats')
          .get();

      if (allMessages.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('🗑️ [AutoDelete] No messages to delete');
        }
        return true;
      }

      if (kDebugMode) {
        debugPrint('🗑️ [AutoDelete] Found ${allMessages.docs.length} messages to delete');
      }

      // Batch delete
      WriteBatch batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in allMessages.docs) {
        batch.delete(doc.reference);
        deleteCount++;

        if (deleteCount >= 450) {
          await batch.commit();
          if (kDebugMode) {
            debugPrint('🗑️ [AutoDelete] Committed batch of $deleteCount deletes');
          }
          batch = _firestore.batch();
          deleteCount = 0;
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
      }

      // Reset last message in chatroom BUT PRESERVE auto-delete settings
      final updateData = <String, dynamic>{
        'lastMessage': '',
        'type': 'text',
      };
      
      // Restore auto-delete settings to ensure they are NOT lost
      if (savedSettings != null) {
        if (savedSettings['autoDeleteEnabled'] != null) {
          updateData['autoDeleteEnabled'] = savedSettings['autoDeleteEnabled'];
        }
        if (savedSettings['autoDeleteDuration'] != null) {
          updateData['autoDeleteDuration'] = savedSettings['autoDeleteDuration'];
        }
        if (savedSettings['autoDeleteUpdatedBy'] != null) {
          updateData['autoDeleteUpdatedBy'] = savedSettings['autoDeleteUpdatedBy'];
        }
        if (savedSettings['autoDeleteUpdatedAt'] != null) {
          updateData['autoDeleteUpdatedAt'] = savedSettings['autoDeleteUpdatedAt'];
        }
        if (savedSettings['users'] != null) {
          updateData['users'] = savedSettings['users'];
        }
      }
      
      await _firestore.collection('chatroom').doc(chatRoomId).update(updateData);
      
      if (kDebugMode) {
        debugPrint('🗑️ [AutoDelete] Updated chatroom with preserved settings: $updateData');
      }
      
      // Also update chat history for all users
      await _updateChatHistoryForAllUsers(chatRoomId, '', 'text', '');

      if (kDebugMode) {
        debugPrint('✅ [AutoDelete] Successfully deleted all ${allMessages.docs.length} messages (settings preserved)');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AutoDelete] Error deleting all messages: $e');
      }
      return false;
    }
  }

  /// Lấy thông tin cài đặt auto-delete của chatroom
  Future<Map<String, dynamic>?> getAutoDeleteSettings(String chatRoomId) async {
    try {
      final doc = await _firestore.collection('chatroom').doc(chatRoomId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'enabled': data['autoDeleteEnabled'] ?? false,
          'duration': data['autoDeleteDuration'] ?? 0,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('❌ [AutoDelete] Error getting settings: $e'); }
      }
      return null;
    }
  }

  /// Trigger xóa ngay lập tức (gọi thủ công khi cần test)
  Future<void> triggerDeleteNow(String chatRoomId) async {
    final settings = await getAutoDeleteSettings(chatRoomId);
    if (settings != null && settings['enabled'] == true && settings['duration'] > 0) {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Manual trigger delete for $chatRoomId'); }
      }
      await _deleteOldMessages(chatRoomId, settings['duration']);
    } else {
      if (kDebugMode) {
        if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Auto-delete is not enabled for $chatRoomId'); }
      }
    }
  }

  /// Format duration để hiển thị cho user
  static String formatDuration(int minutes) {
    if (minutes == 0) return 'Off';
    if (minutes == 1) return '1 minute';
    if (minutes < 60) return '$minutes minutes';
    if (minutes == 60) return '1 hour';
    if (minutes < 1440) return '${minutes ~/ 60} hours';
    if (minutes == 1440) return '24 hours';
    return '${minutes ~/ 1440} days';
  }

  /// Dọn dẹp tất cả resources
  void dispose() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();

    if (kDebugMode) {
      if (kDebugMode) { debugPrint('🗑️ [AutoDelete] Service disposed'); }
    }
  }
}
