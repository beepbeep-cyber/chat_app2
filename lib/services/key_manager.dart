import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'encryption_service.dart';

/// Key Manager - Manages encryption keys for users
/// 
/// Functions:
/// - Generate and store user's RSA key pair
/// - Store public key in Firestore (for other users)
/// - Store private key securely on device
/// - Retrieve other users' public keys for encryption
/// - Backup/restore keys for device migration
class KeyManager {
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Keys for secure storage
  static const String _publicKeyStorageKey = 'e2ee_public_key';
  static const String _privateKeyStorageKey = 'e2ee_private_key';
  static const String _keyInitializedFlag = 'e2ee_keys_initialized';
  
  /// Initialize encryption keys for current user
  /// Call this after user login/signup
  static Future<bool> initializeKeys() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [KeyManager] No current user - cannot initialize keys');
        }
        return false;
      }
      
      if (kDebugMode) {
        debugPrint('🔑 [KeyManager] Initializing keys for user: ${currentUser.uid}');
      }
      
      // Check if keys already exist locally
      final privateKey = await _secureStorage.read(key: _privateKeyStorageKey);
      final publicKey = await _secureStorage.read(key: _publicKeyStorageKey);
      
      if (privateKey != null && publicKey != null) {
        if (kDebugMode) {
          debugPrint('✅ [KeyManager] Keys already exist locally');
        }
        // Ensure public key is synced to Firestore
        await _uploadPublicKeyToFirestore(currentUser.uid, publicKey);
        return true;
      }
      
      // Check if user has keys in Firestore (from another device)
      final firestorePublicKey = await getUserPublicKey(currentUser.uid);
      
      if (firestorePublicKey != null && privateKey == null) {
        // User has keys on another device but not on this one
        // We need to generate new keys (can't recover private key)
        if (kDebugMode) {
          debugPrint('⚠️ [KeyManager] User has keys on Firestore but not locally');
          debugPrint('⚠️ [KeyManager] Generating new key pair...');
        }
      }
      
      // Generate new key pair
      if (kDebugMode) {
        debugPrint('🔑 [KeyManager] Generating new RSA key pair...');
      }
      
      final keyPair = EncryptionService.generateRSAKeyPair();
      
      // Store private key securely on device
      await _secureStorage.write(
        key: _privateKeyStorageKey,
        value: keyPair['privateKey'],
      );
      
      await _secureStorage.write(
        key: _publicKeyStorageKey,
        value: keyPair['publicKey'],
      );
      
      await _secureStorage.write(
        key: _keyInitializedFlag,
        value: 'true',
      );
      
      // Upload public key to Firestore
      await _uploadPublicKeyToFirestore(currentUser.uid, keyPair['publicKey']!);
      
      if (kDebugMode) {
        debugPrint('✅ [KeyManager] Keys initialized successfully');
      }
      
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error initializing keys: $e');
        debugPrint('❌ [KeyManager] Stack trace: $stackTrace');
      }
      return false;
    }
  }
  
  /// Upload public key to Firestore
  static Future<void> _uploadPublicKeyToFirestore(String uid, String publicKey) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'publicKey': publicKey,
        'encryptionEnabled': true,
        'encryptionKeyUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ [KeyManager] Public key uploaded to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error uploading public key: $e');
      }
    }
  }
  
  /// Get current user's private key
  static Future<String?> getPrivateKey() async {
    try {
      final key = await _secureStorage.read(key: _privateKeyStorageKey);
      if (kDebugMode && key != null) {
        debugPrint('✅ [KeyManager] Private key retrieved');
      }
      return key;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error getting private key: $e');
      }
      return null;
    }
  }
  
  /// Get current user's public key
  static Future<String?> getPublicKey() async {
    try {
      final key = await _secureStorage.read(key: _publicKeyStorageKey);
      if (kDebugMode && key != null) {
        debugPrint('✅ [KeyManager] Public key retrieved');
      }
      return key;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error getting public key: $e');
      }
      return null;
    }
  }
  
  /// Get another user's public key from Firestore
  static Future<String?> getUserPublicKey(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final publicKey = userDoc.data()!['publicKey'] as String?;
        if (kDebugMode) {
          debugPrint('🔑 [KeyManager] Got public key for user $userId: ${publicKey != null}');
        }
        return publicKey;
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ [KeyManager] No public key found for user $userId');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error getting user public key: $e');
      }
      return null;
    }
  }
  
  /// Check if user has encryption enabled
  static Future<bool> isEncryptionEnabled(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!['encryptionEnabled'] == true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Delete all keys (for logout or account deletion)
  static Future<void> deleteKeys() async {
    try {
      await _secureStorage.delete(key: _privateKeyStorageKey);
      await _secureStorage.delete(key: _publicKeyStorageKey);
      await _secureStorage.delete(key: _keyInitializedFlag);
      
      if (kDebugMode) {
        debugPrint('✅ [KeyManager] All keys deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error deleting keys: $e');
      }
    }
  }
  
  /// Check if current user has keys initialized
  static Future<bool> hasKeys() async {
    try {
      final privateKey = await _secureStorage.read(key: _privateKeyStorageKey);
      final publicKey = await _secureStorage.read(key: _publicKeyStorageKey);
      final hasKeys = privateKey != null && publicKey != null;
      
      if (kDebugMode) {
        debugPrint('🔑 [KeyManager] hasKeys: $hasKeys');
      }
      
      return hasKeys;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error checking keys: $e');
      }
      return false;
    }
  }
  
  /// Force sync public key to Firestore (for existing users)
  static Future<bool> syncPublicKeyToFirestore() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;
      
      final publicKey = await getPublicKey();
      
      if (publicKey != null) {
        await _uploadPublicKeyToFirestore(currentUser.uid, publicKey);
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [KeyManager] No public key to sync');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error syncing public key: $e');
      }
      return false;
    }
  }
  
  /// Ensure keys are initialized and synced (call on every app launch)
  static Future<bool> ensureKeysReady() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [KeyManager] No user logged in');
        }
        return false;
      }
      
      if (kDebugMode) {
        debugPrint('🔑 [KeyManager] Ensuring keys are ready...');
      }
      
      final hasLocalKeys = await hasKeys();
      
      if (!hasLocalKeys) {
        if (kDebugMode) {
          debugPrint('🔑 [KeyManager] No local keys - initializing...');
        }
        return await initializeKeys();
      }
      
      // Sync to Firestore
      await syncPublicKeyToFirestore();
      
      if (kDebugMode) {
        debugPrint('✅ [KeyManager] Keys are ready');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error ensuring keys ready: $e');
      }
      return false;
    }
  }
  
  /// Force regenerate keys (use when keys are corrupted)
  static Future<bool> regenerateKeys() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;
      
      if (kDebugMode) {
        debugPrint('🔑 [KeyManager] Force regenerating keys...');
      }
      
      // Delete old keys
      await deleteKeys();
      
      // Generate new keys
      return await initializeKeys();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [KeyManager] Error regenerating keys: $e');
      }
      return false;
    }
  }
  
  /// Debug: Get key status info
  static Future<Map<String, dynamic>> getKeyStatus() async {
    final currentUser = _auth.currentUser;
    final hasLocalKeys = await hasKeys();
    final localPublicKey = await getPublicKey();
    final localPrivateKey = await getPrivateKey();
    
    String? firestorePublicKey;
    if (currentUser != null) {
      firestorePublicKey = await getUserPublicKey(currentUser.uid);
    }
    
    return {
      'userId': currentUser?.uid,
      'hasLocalKeys': hasLocalKeys,
      'hasLocalPublicKey': localPublicKey != null,
      'hasLocalPrivateKey': localPrivateKey != null,
      'publicKeyInFirestore': firestorePublicKey != null,
      'keysMatch': localPublicKey == firestorePublicKey,
    };
  }
}
