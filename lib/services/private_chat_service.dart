import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
// Note: Using FlutterSecureStorage for local caching + Firestore for persistence

/// Service để quản lý Private Chats với mật khẩu bảo vệ
/// Lưu trữ kết hợp: FlutterSecureStorage (local) + Firestore (cloud backup)
class PrivateChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Keys for storage
  static const String _privatePasswordKey = 'private_chat_password';
  static const String _privateChatIdsKey = 'private_chat_ids';
  static const String _lastAuthKey = 'private_chat_last_auth';
  
  // Session timeout (30 minutes - longer timeout for better UX)
  static const int _sessionTimeoutMinutes = 30;
  
  // In-memory session cache for current app session
  static bool _isSessionAuthenticated = false;
  static DateTime? _lastAuthTime;
  
  /// Check if user has set up Private Chat password
  /// Checks Firestore first (reliable), then local storage as backup
  static Future<bool> hasPassword() async {
    try {
      // Check Firestore FIRST (most reliable, persists across reinstalls)
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        debugPrint('🔐 PrivateChatService: Checking password for user: $userId');
        
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('privateChatSettings')
            .doc('config')
            .get();
        
        if (doc.exists && doc.data()?['passwordHash'] != null) {
          final cloudHash = doc.data()!['passwordHash'] as String;
          if (cloudHash.isNotEmpty) {
            debugPrint('✅ PrivateChatService: Password found in Firestore');
            // Sync to local storage for faster future access
            try {
              await _secureStorage.write(key: _privatePasswordKey, value: cloudHash);
              debugPrint('✅ PrivateChatService: Synced password to local storage');
            } catch (localError) {
              debugPrint('⚠️ PrivateChatService: Could not sync to local: $localError');
            }
            return true;
          }
        }
        debugPrint('⚠️ PrivateChatService: No password in Firestore');
      }
      
      // Fallback to local storage (in case Firestore fails)
      try {
        final localPassword = await _secureStorage.read(key: _privatePasswordKey);
        if (localPassword != null && localPassword.isNotEmpty) {
          debugPrint('✅ PrivateChatService: Password found in local storage');
          return true;
        }
      } catch (localError) {
        debugPrint('⚠️ PrivateChatService: Local storage read error: $localError');
      }
      
      debugPrint('❌ PrivateChatService: No password found anywhere');
      return false;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error checking password: $e');
      return false;
    }
  }
  
  /// Set up new password for Private Chat
  /// Stores in both local storage and Firestore for persistence
  static Future<bool> setPassword(String password) async {
    try {
      if (password.length < 4) {
        throw Exception('Password must be at least 4 characters');
      }
      
      // Hash password before storing
      final hashedPassword = _hashPassword(password);
      
      // Save to local storage
      await _secureStorage.write(key: _privatePasswordKey, value: hashedPassword);
      
      // Save to Firestore for cloud backup (persists across browser sessions/devices)
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('privateChatSettings')
            .doc('config')
            .set({
          'passwordHash': hashedPassword,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ PrivateChatService: Password saved to cloud backup');
      }
      
      debugPrint('✅ PrivateChatService: Password set successfully');
      return true;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error setting password: $e');
      return false;
    }
  }
  
  /// Verify password
  /// First checks local storage, then falls back to Firestore
  static Future<bool> verifyPassword(String password) async {
    try {
      String? storedHash;
      
      // Try local storage first
      storedHash = await _secureStorage.read(key: _privatePasswordKey);
      
      // If not in local, try Firestore
      if (storedHash == null || storedHash.isEmpty) {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final doc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('privateChatSettings')
              .doc('config')
              .get();
          
          if (doc.exists) {
            storedHash = doc.data()?['passwordHash'] as String?;
            // Sync to local storage
            if (storedHash != null) {
              await _secureStorage.write(key: _privatePasswordKey, value: storedHash);
              debugPrint('✅ PrivateChatService: Synced password hash from cloud');
            }
          }
        }
      }
      
      if (storedHash == null) return false;
      
      final inputHash = _hashPassword(password);
      final isValid = storedHash == inputHash;
      
      if (isValid) {
        // Update last auth time for session management
        await _updateLastAuthTime();
      }
      
      return isValid;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error verifying password: $e');
      return false;
    }
  }
  
  /// Change password
  static Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final isOldValid = await verifyPassword(oldPassword);
      if (!isOldValid) {
        throw Exception('Current password is incorrect');
      }
      
      return await setPassword(newPassword);
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error changing password: $e');
      return false;
    }
  }
  
  /// Reset password (requires re-authentication)
  static Future<bool> resetPassword() async {
    try {
      await _secureStorage.delete(key: _privatePasswordKey);
      await _secureStorage.delete(key: _privateChatIdsKey);
      await _secureStorage.delete(key: _lastAuthKey);
      
      debugPrint('✅ PrivateChatService: Password reset successfully');
      return true;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error resetting password: $e');
      return false;
    }
  }
  
  /// Check if session is still valid
  /// Uses in-memory cache first, then local storage, then Firestore
  static Future<bool> isSessionValid() async {
    try {
      // Check in-memory session first (fastest)
      if (_isSessionAuthenticated && _lastAuthTime != null) {
        final difference = DateTime.now().difference(_lastAuthTime!).inMinutes;
        if (difference < _sessionTimeoutMinutes) {
          return true;
        }
      }
      
      // Try local storage
      final lastAuthStr = await _secureStorage.read(key: _lastAuthKey);
      if (lastAuthStr != null) {
        final lastAuth = DateTime.parse(lastAuthStr);
        final now = DateTime.now();
        final difference = now.difference(lastAuth).inMinutes;
        
        if (difference < _sessionTimeoutMinutes) {
          // Update in-memory cache
          _isSessionAuthenticated = true;
          _lastAuthTime = lastAuth;
          return true;
        }
      }
      
      // Fallback to Firestore (cloud backup)
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('privateChatSettings')
            .doc('config')
            .get();
        
        if (doc.exists && doc.data()?['lastAuthTime'] != null) {
          final timestamp = doc.data()!['lastAuthTime'] as Timestamp;
          final lastAuth = timestamp.toDate();
          final difference = DateTime.now().difference(lastAuth).inMinutes;
          
          if (difference < _sessionTimeoutMinutes) {
            // Sync to local storage and memory
            await _secureStorage.write(key: _lastAuthKey, value: lastAuth.toIso8601String());
            _isSessionAuthenticated = true;
            _lastAuthTime = lastAuth;
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error checking session: $e');
      return false;
    }
  }
  
  /// Update last auth time
  /// Stores in memory, local storage, and Firestore
  static Future<void> _updateLastAuthTime() async {
    final now = DateTime.now();
    
    // Update in-memory cache
    _isSessionAuthenticated = true;
    _lastAuthTime = now;
    
    // Save to local storage
    await _secureStorage.write(
      key: _lastAuthKey, 
      value: now.toIso8601String(),
    );
    
    // Save to Firestore for cloud backup
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChatSettings')
          .doc('config')
          .set({
        'lastAuthTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
  
  /// Hash password using SHA256
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'letchatt_private_salt');
    return sha256.convert(bytes).toString();
  }
  
  /// Add chat to private list
  static Future<bool> addToPrivate({
    required String chatRoomId,
    required String chatName,
    required String chatAvatar,
    required String chatType, // 'p2p' or 'group'
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      // Store in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChats')
          .doc(chatRoomId)
          .set({
        'chatRoomId': chatRoomId,
        'chatName': chatName,
        'chatAvatar': chatAvatar,
        'chatType': chatType,
        'addedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ PrivateChatService: Chat added to private: $chatRoomId');
      return true;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error adding to private: $e');
      return false;
    }
  }
  
  /// Remove chat from private list
  static Future<bool> removeFromPrivate(String chatRoomId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChats')
          .doc(chatRoomId)
          .delete();
      
      debugPrint('✅ PrivateChatService: Chat removed from private: $chatRoomId');
      return true;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error removing from private: $e');
      return false;
    }
  }
  
  /// Check if chat is in private list
  static Future<bool> isPrivate(String chatRoomId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChats')
          .doc(chatRoomId)
          .get();
      
      return doc.exists;
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error checking private status: $e');
      return false;
    }
  }
  
  /// Get all private chat IDs
  static Future<List<String>> getPrivateChatIds() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChats')
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('❌ PrivateChatService: Error getting private chat IDs: $e');
      return [];
    }
  }
  
  /// Get all private chats
  static Stream<QuerySnapshot> getPrivateChatsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('privateChats')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }
  
  /// Get private chats count
  static Future<int> getPrivateChatsCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChats')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Clear session (logout from private)
  /// Clears memory, local storage, and Firestore session data
  static Future<void> clearSession() async {
    // Clear in-memory session
    _isSessionAuthenticated = false;
    _lastAuthTime = null;
    
    // Clear local storage
    await _secureStorage.delete(key: _lastAuthKey);
    
    // Clear Firestore session (optional - only lastAuthTime, not password)
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('privateChatSettings')
          .doc('config')
          .update({
        'lastAuthTime': FieldValue.delete(),
      }).catchError((e) {
        // Ignore if doc doesn't exist
        debugPrint('⚠️ PrivateChatService: Could not clear Firestore session: $e');
      });
    }
    
    debugPrint('✅ PrivateChatService: Session cleared');
  }
}
