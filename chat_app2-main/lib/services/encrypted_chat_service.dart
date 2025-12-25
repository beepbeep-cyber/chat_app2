import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'encryption_service.dart';
import 'key_manager.dart';
import 'package:flutter/foundation.dart';

/// Encrypted Chat Service
///
/// Provides high-level methods for sending and receiving encrypted messages
/// 
/// FIX: Now encrypts messages for BOTH sender and recipient so sender can also read their own messages
class EncryptedChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send an encrypted text message
  ///
  /// Parameters:
  /// - recipientUid: User ID of the recipient
  /// - message: Plain text message
  /// - chatRoomId: Chat room document ID
  /// - additionalData: Any extra fields to add to the message
  ///
  /// Returns: true if successful, false otherwise
  static Future<bool> sendEncryptedMessage({
    required String recipientUid,
    required String message,
    required String chatRoomId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get recipient's public key
      final recipientPublicKey = await KeyManager.getUserPublicKey(recipientUid);

      if (recipientPublicKey == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [E2EE] Recipient does not have encryption enabled');
        }
        return false;
      }

      // Get sender's public key (for self-decryption)
      final senderPublicKey = await KeyManager.getPublicKey();
      
      if (senderPublicKey == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [E2EE] Sender does not have encryption keys');
        }
        return false;
      }

      // Encrypt the message for RECIPIENT
      final recipientEncryptedData = EncryptionService.encryptMessage(
        message,
        recipientPublicKey,
      );

      // Encrypt the message for SENDER (so sender can also read their own messages)
      final senderEncryptedData = EncryptionService.encryptMessage(
        message,
        senderPublicKey,
      );

      if (kDebugMode) {
        debugPrint('🔐 [E2EE] Message encrypted for both sender and recipient');
      }

      // Prepare message data with BOTH encrypted versions
      final messageData = {
        'sendBy': currentUser.displayName,
        'senderUid': currentUser.uid,
        'encrypted': true,
        // For recipient to decrypt
        'encryptedMessage': recipientEncryptedData['encryptedMessage'],
        'encryptedAESKey': recipientEncryptedData['encryptedAESKey'],
        'iv': recipientEncryptedData['iv'],
        // For sender to decrypt their own message
        'senderEncryptedMessage': senderEncryptedData['encryptedMessage'],
        'senderEncryptedAESKey': senderEncryptedData['encryptedAESKey'],
        'senderIv': senderEncryptedData['iv'],
        'type': 'text',
        'timeStamp': DateTime.now(),
        ...?additionalData,
      };

      // Send to Firestore
      await _firestore
          .collection('chatroom')
          .doc(chatRoomId)
          .collection('chats')
          .add(messageData);

      if (kDebugMode) {
        debugPrint('✅ [E2EE] Encrypted message sent successfully');
      }

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [E2EE] Error sending encrypted message: $e');
        debugPrint('❌ [E2EE] Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Decrypt a received message
  ///
  /// Parameters:
  /// - messageData: Map containing encrypted message data from Firestore
  ///
  /// Returns: Decrypted message string, or error message if decryption fails
  static Future<String> decryptMessage(Map<String, dynamic> messageData) async {
    try {
      // Check if message is encrypted
      if (messageData['encrypted'] != true) {
        // Return original message if not encrypted
        return messageData['message'] ?? '';
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return '[Not logged in]';
      }

      // Get user's private key
      final privateKey = await KeyManager.getPrivateKey();

      if (privateKey == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [E2EE] Private key not found - attempting to restore');
        }
        // Try to restore keys
        await KeyManager.ensureKeysReady();
        final restoredKey = await KeyManager.getPrivateKey();
        if (restoredKey == null) {
          return '[Encryption keys not found - please re-login]';
        }
      }

      final keyToUse = privateKey ?? await KeyManager.getPrivateKey();
      if (keyToUse == null) return '[Key error]';

      // Check if current user is the sender
      final isSender = messageData['senderUid'] == currentUser.uid ||
                       messageData['sendBy'] == currentUser.displayName;

      Map<String, String> encryptedData;

      if (isSender && messageData['senderEncryptedMessage'] != null) {
        // Sender reading their own message - use sender's encrypted version
        encryptedData = {
          'encryptedMessage': messageData['senderEncryptedMessage'] as String,
          'encryptedAESKey': messageData['senderEncryptedAESKey'] as String,
          'iv': messageData['senderIv'] as String,
        };
        if (kDebugMode) {
          debugPrint('🔐 [E2EE] Decrypting as SENDER');
        }
      } else {
        // Recipient reading message - use recipient's encrypted version
        encryptedData = {
          'encryptedMessage': messageData['encryptedMessage'] as String,
          'encryptedAESKey': messageData['encryptedAESKey'] as String,
          'iv': messageData['iv'] as String,
        };
        if (kDebugMode) {
          debugPrint('🔐 [E2EE] Decrypting as RECIPIENT');
        }
      }

      // Decrypt message
      final decryptedMessage = EncryptionService.decryptMessage(
        encryptedData,
        keyToUse,
      );

      if (kDebugMode) {
        debugPrint('✅ [E2EE] Message decrypted successfully');
      }

      return decryptedMessage;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [E2EE] Error decrypting message: $e');
        debugPrint('❌ [E2EE] Stack trace: $stackTrace');
      }
      return '[Decryption failed]';
    }
  }

  /// Check if both users have encryption enabled
  static Future<bool> canEncryptChat(String otherUserId) async {
    try {
      // Check if current user has keys
      final hasCurrentUserKeys = await KeyManager.hasKeys();

      if (!hasCurrentUserKeys) {
        if (kDebugMode) {
          debugPrint('⚠️ [E2EE] Current user has no keys - initializing...');
        }
        // Try to initialize keys
        await KeyManager.ensureKeysReady();
        final hasKeysNow = await KeyManager.hasKeys();
        if (!hasKeysNow) {
          if (kDebugMode) {
            debugPrint('❌ [E2EE] Failed to initialize keys for current user');
          }
          return false;
        }
      }

      // Check if other user has encryption enabled
      final otherUserPublicKey = await KeyManager.getUserPublicKey(otherUserId);

      if (otherUserPublicKey == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [E2EE] Other user ($otherUserId) has no public key');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('✅ [E2EE] Both users have encryption enabled');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [E2EE] Error checking encryption capability: $e');
      }
      return false;
    }
  }

  /// Send unencrypted message (fallback)
  static Future<bool> sendUnencryptedMessage({
    required String message,
    required String chatRoomId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final messageData = {
        'sendBy': currentUser.displayName,
        'senderUid': currentUser.uid,
        'message': message,
        'encrypted': false,
        'type': 'text',
        'timeStamp': DateTime.now(),
        ...?additionalData,
      };

      await _firestore
          .collection('chatroom')
          .doc(chatRoomId)
          .collection('chats')
          .add(messageData);

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [E2EE] Error sending message: $e');
      }
      return false;
    }
  }

  /// Debug: Check E2EE status for a chat
  static Future<Map<String, dynamic>> debugE2EEStatus(String otherUserId) async {
    final currentUser = _auth.currentUser;
    final hasLocalKeys = await KeyManager.hasKeys();
    final localPublicKey = await KeyManager.getPublicKey();
    final localPrivateKey = await KeyManager.getPrivateKey();
    final otherPublicKey = await KeyManager.getUserPublicKey(otherUserId);

    return {
      'currentUserId': currentUser?.uid,
      'hasLocalKeys': hasLocalKeys,
      'hasLocalPublicKey': localPublicKey != null,
      'hasLocalPrivateKey': localPrivateKey != null,
      'otherUserId': otherUserId,
      'otherUserHasPublicKey': otherPublicKey != null,
      'canEncrypt': hasLocalKeys && otherPublicKey != null,
    };
  }
}
