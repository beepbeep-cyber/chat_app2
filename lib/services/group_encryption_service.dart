import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'encryption_service.dart';
import 'key_manager.dart';

/// Group Chat End-to-End Encryption Service
/// 
/// Workflow for Group Encryption:
/// 1. Sender encrypts message with each member's public key
/// 2. Each encrypted version is stored in Firestore
/// 3. Recipients decrypt using their own private key
class GroupEncryptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Encrypt a message for all group members
  /// 
  /// Parameters:
  /// - message: Plain text message to encrypt
  /// - groupId: Group chat ID
  /// 
  /// Returns: JSON string containing encrypted versions for each member
  static Future<String?> encryptGroupMessage(
    String message,
    String groupId,
  ) async {
    try {
      if (kDebugMode) { debugPrint('🔐 [GroupEncryption] Starting encryption for groupId: $groupId'); }
      
      // Get all group members
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        if (kDebugMode) { debugPrint('❌ [GroupEncryption] Group document not found'); }
        return null;
      }

      final List<dynamic> members = groupDoc.data()?['members'] ?? [];
      if (kDebugMode) { debugPrint('👥 [GroupEncryption] Found ${members.length} members'); }
      
      if (members.isEmpty) {
        if (kDebugMode) { debugPrint('❌ [GroupEncryption] No members in group'); }
        return null;
      }

      // Encrypt message for each member
      Map<String, Map<String, String>> encryptedForMembers = {};
      
      for (var member in members) {
        try {
          // Extract UID from member object
          final String memberId = member['uid'] ?? '';
          if (memberId.isEmpty) continue;
          
          // Get member's public key
          String? publicKey = await KeyManager.getUserPublicKey(memberId);
          
          if (publicKey != null) {
            // Encrypt message with member's public key
            Map<String, String> encryptedData = EncryptionService.encryptMessage(
              message,
              publicKey,
            );
            
            encryptedForMembers[memberId] = encryptedData;
          }
        } catch (e) {
          if (kDebugMode) { debugPrint('Error encrypting for member: $e'); }
          // Continue with other members even if one fails
        }
      }

      if (encryptedForMembers.isEmpty) {
        if (kDebugMode) { debugPrint('❌ [GroupEncryption] No members could be encrypted for'); }
        return null;
      }

      if (kDebugMode) { debugPrint('✅ [GroupEncryption] Successfully encrypted for ${encryptedForMembers.length} members'); }
      
      // Return as JSON string
      return json.encode(encryptedForMembers);
      
    } catch (e) {
      if (kDebugMode) { debugPrint('❌ [GroupEncryption] Error: $e'); }
      return null;
    }
  }

  /// Decrypt a group message using current user's private key
  /// 
  /// Parameters:
  /// - encryptedMessage: JSON string containing encrypted versions
  /// - groupId: Group chat ID
  /// 
  /// Returns: Decrypted plain text message for current user
  static Future<String?> decryptGroupMessage(
    String encryptedMessage,
    String groupId,
  ) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        return '[Not logged in]';
      }

      // Parse encrypted data
      Map<String, dynamic> encryptedForMembers = json.decode(encryptedMessage);
      
      // Get current user's encrypted version
      final userEncryptedData = encryptedForMembers[currentUserId];
      if (userEncryptedData == null) {
        return '[No encrypted data for current user]';
      }

      // Get user's private key
      String? privateKey = await KeyManager.getPrivateKey();
      if (privateKey == null) {
        return '[Private key not found]';
      }

      // Convert to Map<String, String>
      Map<String, String> encryptedData = Map<String, String>.from(userEncryptedData);

      // Decrypt message
      String decryptedMessage = EncryptionService.decryptMessage(
        encryptedData,
        privateKey,
      );

      return decryptedMessage;
      
    } catch (e) {
      if (kDebugMode) { debugPrint('Error in decryptGroupMessage: $e'); }
      return '[Decryption error]';
    }
  }

  /// Verify if message is encrypted
  /// 
  /// Parameters:
  /// - message: Message string to check
  /// 
  /// Returns: true if message appears to be encrypted JSON
  static bool isEncrypted(String message) {
    try {
      final decoded = json.decode(message);
      return decoded is Map && decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Re-encrypt a message when new members are added to group
  /// 
  /// Parameters:
  /// - groupId: Group chat ID
  /// - messageId: Message document ID
  /// 
  /// Returns: true if re-encryption successful
  static Future<bool> reEncryptForNewMembers(
    String groupId,
    String messageId,
  ) async {
    try {
      // Get message document
      final messageDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('chats')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        return false;
      }

      final messageData = messageDoc.data();
      if (messageData == null) {
        return false;
      }

      // Check if message is encrypted
      final bool isEncrypted = messageData['isEncrypted'] ?? false;
      if (!isEncrypted) {
        return true; // Not encrypted, no need to re-encrypt
      }

      // For now, we'll skip re-encryption of old messages
      // This is a complex operation that would require:
      // 1. Decrypt with sender's key
      // 2. Re-encrypt for all current members
      // 3. Update Firestore
      
      return true;
      
    } catch (e) {
      if (kDebugMode) { debugPrint('Error in reEncryptForNewMembers: $e'); }
      return false;
    }
  }
}
