import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Test file for E2EE (End-to-End Encryption) logic
/// Tests RSA+AES encryption workflow used in chat_app2

// ==================== MOCK ENCRYPTION SERVICE ====================
class MockEncryptionService {
  /// Generate RSA Key Pair for a user
  static Map<String, String> generateRSAKeyPair() {
    final keyGen = RSAKeyGenerator();
    
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    
    final params = RSAKeyGeneratorParameters(
      BigInt.parse('65537'),
      2048,
      64,
    );
    
    final keyGenParams = ParametersWithRandom(params, secureRandom);
    keyGen.init(keyGenParams);
    
    final keyPair = keyGen.generateKeyPair();
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    
    return {
      'publicKey': _encodePublicKeyToPem(publicKey),
      'privateKey': _encodePrivateKeyToPem(privateKey),
    };
  }
  
  static Map<String, String> encryptMessage(String message, String recipientPublicKey) {
    // Handle empty message edge case
    final messageToEncrypt = message.isEmpty ? ' ' : message;
    
    final aesKey = encrypt_pkg.Key.fromSecureRandom(32);
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(aesKey, mode: encrypt_pkg.AESMode.cbc),
    );
    final encryptedMessage = encrypter.encrypt(messageToEncrypt, iv: iv);
    
    final publicKey = _parsePublicKeyFromPem(recipientPublicKey);
    final rsaEncrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.RSA(publicKey: publicKey),
    );
    final encryptedAESKey = rsaEncrypter.encryptBytes(aesKey.bytes);
    
    return {
      'encryptedMessage': encryptedMessage.base64,
      'encryptedAESKey': encryptedAESKey.base64,
      'iv': iv.base64,
    };
  }
  
  static String decryptMessage(Map<String, String> encryptedData, String privateKey) {
    try {
      final encryptedMessage = encrypt_pkg.Encrypted.fromBase64(
        encryptedData['encryptedMessage']!,
      );
      final encryptedAESKey = encrypt_pkg.Encrypted.fromBase64(
        encryptedData['encryptedAESKey']!,
      );
      final iv = encrypt_pkg.IV.fromBase64(encryptedData['iv']!);
      
      final rsaPrivateKey = _parsePrivateKeyFromPem(privateKey);
      final rsaEncrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.RSA(privateKey: rsaPrivateKey),
      );
      final aesKeyBytes = rsaEncrypter.decryptBytes(encryptedAESKey);
      final aesKey = encrypt_pkg.Key(Uint8List.fromList(aesKeyBytes));
      
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(aesKey, mode: encrypt_pkg.AESMode.cbc),
      );
      final decryptedMessage = encrypter.decrypt(encryptedMessage, iv: iv);
      
      // Handle empty message edge case
      return decryptedMessage.trim().isEmpty ? '' : decryptedMessage;
    } catch (e) {
      return '[Decryption Error: Unable to decrypt message]';
    }
  }
  
  static String generateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  static String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final modulus = publicKey.modulus!.toString();
    final exponent = publicKey.exponent!.toString();
    
    final keyData = {
      'modulus': modulus,
      'exponent': exponent,
    };
    
    return base64.encode(utf8.encode(json.encode(keyData)));
  }
  
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final modulus = privateKey.modulus!.toString();
    final exponent = privateKey.exponent!.toString();
    final p = privateKey.p!.toString();
    final q = privateKey.q!.toString();
    
    final keyData = {
      'modulus': modulus,
      'exponent': exponent,
      'p': p,
      'q': q,
    };
    
    return base64.encode(utf8.encode(json.encode(keyData)));
  }
  
  static RSAPublicKey _parsePublicKeyFromPem(String pem) {
    final keyData = json.decode(utf8.decode(base64.decode(pem)));
    final modulus = BigInt.parse(keyData['modulus']);
    final exponent = BigInt.parse(keyData['exponent']);
    
    return RSAPublicKey(modulus, exponent);
  }
  
  static RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final keyData = json.decode(utf8.decode(base64.decode(pem)));
    final modulus = BigInt.parse(keyData['modulus']);
    final exponent = BigInt.parse(keyData['exponent']);
    final p = BigInt.parse(keyData['p']);
    final q = BigInt.parse(keyData['q']);
    
    return RSAPrivateKey(modulus, exponent, p, q);
  }
}

// ==================== MOCK ENCRYPTED CHAT SERVICE ====================
class MockEncryptedChatService {
  static final Map<String, String> _userKeys = {}; // userId -> publicKey
  
  static void setUserPublicKey(String userId, String publicKey) {
    _userKeys[userId] = publicKey;
  }
  
  static String? getUserPublicKey(String userId) {
    return _userKeys[userId];
  }
  
  static void clearKeys() {
    _userKeys.clear();
  }
  
  /// Simulate sending an encrypted message (dual encryption for sender + recipient)
  static Map<String, dynamic>? sendEncryptedMessage({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String message,
    required String senderPublicKey,
  }) {
    final recipientPublicKey = _userKeys[recipientId];
    
    if (recipientPublicKey == null || senderPublicKey.isEmpty) {
      return null; // Cannot encrypt
    }
    
    // Encrypt for recipient
    final recipientEncryptedData = MockEncryptionService.encryptMessage(
      message,
      recipientPublicKey,
    );
    
    // Encrypt for sender (so sender can also read their own messages)
    final senderEncryptedData = MockEncryptionService.encryptMessage(
      message,
      senderPublicKey,
    );
    
    return {
      'sendBy': senderName,
      'senderUid': senderId,
      'encrypted': true,
      // For recipient
      'encryptedMessage': recipientEncryptedData['encryptedMessage'],
      'encryptedAESKey': recipientEncryptedData['encryptedAESKey'],
      'iv': recipientEncryptedData['iv'],
      // For sender
      'senderEncryptedMessage': senderEncryptedData['encryptedMessage'],
      'senderEncryptedAESKey': senderEncryptedData['encryptedAESKey'],
      'senderIv': senderEncryptedData['iv'],
      'type': 'text',
      'timeStamp': DateTime.now(),
    };
  }
  
  /// Simulate decrypting a message
  static String decryptMessage({
    required Map<String, dynamic> messageData,
    required String currentUserId,
    required String currentUserPrivateKey,
  }) {
    if (messageData['encrypted'] != true) {
      return messageData['message'] ?? '';
    }
    
    final isSender = messageData['senderUid'] == currentUserId;
    
    Map<String, String> encryptedData;
    
    if (isSender && messageData['senderEncryptedMessage'] != null) {
      // Sender reading their own message
      encryptedData = {
        'encryptedMessage': messageData['senderEncryptedMessage'] as String,
        'encryptedAESKey': messageData['senderEncryptedAESKey'] as String,
        'iv': messageData['senderIv'] as String,
      };
    } else {
      // Recipient reading message
      encryptedData = {
        'encryptedMessage': messageData['encryptedMessage'] as String,
        'encryptedAESKey': messageData['encryptedAESKey'] as String,
        'iv': messageData['iv'] as String,
      };
    }
    
    return MockEncryptionService.decryptMessage(encryptedData, currentUserPrivateKey);
  }
}

// ==================== TEST CASES ====================
void main() {
  group('🔐 EncryptionService Tests', () {
    test('✅ TEST 1: RSA Key Pair Generation', () {
      print('\n--- TEST 1: RSA Key Pair Generation ---');
      
      final keyPair = MockEncryptionService.generateRSAKeyPair();
      
      expect(keyPair['publicKey'], isNotNull);
      expect(keyPair['privateKey'], isNotNull);
      expect(keyPair['publicKey']!.isNotEmpty, true);
      expect(keyPair['privateKey']!.isNotEmpty, true);
      
      // Verify keys are valid base64
      expect(() => base64.decode(keyPair['publicKey']!), returnsNormally);
      expect(() => base64.decode(keyPair['privateKey']!), returnsNormally);
      
      print('✓ Public Key generated: ${keyPair['publicKey']!.substring(0, 50)}...');
      print('✓ Private Key generated: ${keyPair['privateKey']!.substring(0, 50)}...');
      print('✅ TEST 1 PASSED: Key pair generation works correctly');
    });
    
    test('✅ TEST 2: Basic Message Encryption/Decryption', () {
      print('\n--- TEST 2: Basic Message Encryption/Decryption ---');
      
      final keyPair = MockEncryptionService.generateRSAKeyPair();
      final originalMessage = 'Hello, this is a secret message! 🔐';
      
      // Encrypt
      final encryptedData = MockEncryptionService.encryptMessage(
        originalMessage,
        keyPair['publicKey']!,
      );
      
      expect(encryptedData['encryptedMessage'], isNotNull);
      expect(encryptedData['encryptedAESKey'], isNotNull);
      expect(encryptedData['iv'], isNotNull);
      
      print('✓ Original message: $originalMessage');
      print('✓ Encrypted message: ${encryptedData['encryptedMessage']!.substring(0, 30)}...');
      
      // Decrypt
      final decryptedMessage = MockEncryptionService.decryptMessage(
        encryptedData,
        keyPair['privateKey']!,
      );
      
      expect(decryptedMessage, equals(originalMessage));
      print('✓ Decrypted message: $decryptedMessage');
      print('✅ TEST 2 PASSED: Encryption/Decryption works correctly');
    });
    
    test('✅ TEST 3: Different Users Cannot Decrypt Each Other\'s Messages', () {
      print('\n--- TEST 3: Cross-User Decryption Security ---');
      
      final user1Keys = MockEncryptionService.generateRSAKeyPair();
      final user2Keys = MockEncryptionService.generateRSAKeyPair();
      
      final messageToUser1 = 'Secret message for User 1';
      
      // Encrypt message for User1
      final encryptedData = MockEncryptionService.encryptMessage(
        messageToUser1,
        user1Keys['publicKey']!,
      );
      
      // User1 should be able to decrypt
      final user1Decrypted = MockEncryptionService.decryptMessage(
        encryptedData,
        user1Keys['privateKey']!,
      );
      expect(user1Decrypted, equals(messageToUser1));
      print('✓ User1 can decrypt: $user1Decrypted');
      
      // User2 should NOT be able to decrypt
      final user2Decrypted = MockEncryptionService.decryptMessage(
        encryptedData,
        user2Keys['privateKey']!,
      );
      expect(user2Decrypted, equals('[Decryption Error: Unable to decrypt message]'));
      print('✓ User2 cannot decrypt: $user2Decrypted');
      
      print('✅ TEST 3 PASSED: Cross-user decryption blocked correctly');
    });
    
    test('✅ TEST 4: Hash Generation', () {
      print('\n--- TEST 4: Hash Generation ---');
      
      final data = 'Hello World';
      final hash1 = MockEncryptionService.generateHash(data);
      final hash2 = MockEncryptionService.generateHash(data);
      final differentHash = MockEncryptionService.generateHash('Different Data');
      
      expect(hash1, equals(hash2)); // Same data = same hash
      expect(hash1, isNot(equals(differentHash))); // Different data = different hash
      expect(hash1.length, equals(64)); // SHA-256 produces 64 hex chars
      
      print('✓ Hash of "$data": $hash1');
      print('✓ Same data produces same hash: ${hash1 == hash2}');
      print('✓ Different data produces different hash: ${hash1 != differentHash}');
      print('✅ TEST 4 PASSED: Hash generation works correctly');
    });
    
    test('✅ TEST 5: Unicode and Emoji Support', () {
      print('\n--- TEST 5: Unicode and Emoji Support ---');
      
      final keyPair = MockEncryptionService.generateRSAKeyPair();
      final messages = [
        'Hello 世界! 🌍',
        'Xin chào Việt Nam! 🇻🇳',
        '日本語テスト 🎌',
        '🔐💬📱🚀✨',
        'Mixed: ABC 123 !@# 中文 🎉',
      ];
      
      for (final message in messages) {
        final encryptedData = MockEncryptionService.encryptMessage(
          message,
          keyPair['publicKey']!,
        );
        
        final decrypted = MockEncryptionService.decryptMessage(
          encryptedData,
          keyPair['privateKey']!,
        );
        
        expect(decrypted, equals(message));
        print('✓ "$message" → encrypted → "$decrypted"');
      }
      
      print('✅ TEST 5 PASSED: Unicode and emoji support works correctly');
    });
    
    test('✅ TEST 6: Long Message Encryption', () {
      print('\n--- TEST 6: Long Message Encryption ---');
      
      final keyPair = MockEncryptionService.generateRSAKeyPair();
      final longMessage = 'A' * 10000; // 10KB message
      
      final encryptedData = MockEncryptionService.encryptMessage(
        longMessage,
        keyPair['publicKey']!,
      );
      
      final decrypted = MockEncryptionService.decryptMessage(
        encryptedData,
        keyPair['privateKey']!,
      );
      
      expect(decrypted, equals(longMessage));
      expect(decrypted.length, equals(10000));
      
      print('✓ Original message length: ${longMessage.length}');
      print('✓ Encrypted message length: ${encryptedData['encryptedMessage']!.length}');
      print('✓ Decrypted message length: ${decrypted.length}');
      print('✅ TEST 6 PASSED: Long message encryption works correctly');
    });
  });
  
  group('💬 EncryptedChatService Tests', () {
    setUp(() {
      MockEncryptedChatService.clearKeys();
    });
    
    test('✅ TEST 7: Dual Encryption (Sender + Recipient)', () {
      print('\n--- TEST 7: Dual Encryption (Sender + Recipient) ---');
      
      // Generate keys for both users
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      
      // Register public keys
      MockEncryptedChatService.setUserPublicKey('alice_uid', aliceKeys['publicKey']!);
      MockEncryptedChatService.setUserPublicKey('bob_uid', bobKeys['publicKey']!);
      
      // Alice sends message to Bob
      final messageData = MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid',
        message: 'Hello Bob! This is encrypted 🔐',
        senderPublicKey: aliceKeys['publicKey']!,
      );
      
      expect(messageData, isNotNull);
      expect(messageData!['encrypted'], true);
      expect(messageData['senderUid'], 'alice_uid');
      
      // Verify both encryption versions exist
      expect(messageData['encryptedMessage'], isNotNull); // For Bob
      expect(messageData['senderEncryptedMessage'], isNotNull); // For Alice
      
      print('✓ Message encrypted for both sender and recipient');
      print('✓ Recipient encrypted data present: ${messageData['encryptedMessage'] != null}');
      print('✓ Sender encrypted data present: ${messageData['senderEncryptedMessage'] != null}');
      
      print('✅ TEST 7 PASSED: Dual encryption works correctly');
    });
    
    test('✅ TEST 8: Sender Can Read Own Messages', () {
      print('\n--- TEST 8: Sender Can Read Own Messages ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockEncryptedChatService.setUserPublicKey('alice_uid', aliceKeys['publicKey']!);
      MockEncryptedChatService.setUserPublicKey('bob_uid', bobKeys['publicKey']!);
      
      final originalMessage = 'Hello Bob!';
      
      // Alice sends message
      final messageData = MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid',
        message: originalMessage,
        senderPublicKey: aliceKeys['publicKey']!,
      )!;
      
      // Alice (sender) reads her own message
      final aliceDecrypted = MockEncryptedChatService.decryptMessage(
        messageData: messageData,
        currentUserId: 'alice_uid',
        currentUserPrivateKey: aliceKeys['privateKey']!,
      );
      
      expect(aliceDecrypted, equals(originalMessage));
      print('✓ Alice (sender) can read her own message: $aliceDecrypted');
      
      print('✅ TEST 8 PASSED: Sender can read own messages');
    });
    
    test('✅ TEST 9: Recipient Can Read Messages', () {
      print('\n--- TEST 9: Recipient Can Read Messages ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockEncryptedChatService.setUserPublicKey('alice_uid', aliceKeys['publicKey']!);
      MockEncryptedChatService.setUserPublicKey('bob_uid', bobKeys['publicKey']!);
      
      final originalMessage = 'Hello Bob!';
      
      // Alice sends message
      final messageData = MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid',
        message: originalMessage,
        senderPublicKey: aliceKeys['publicKey']!,
      )!;
      
      // Bob (recipient) reads the message
      final bobDecrypted = MockEncryptedChatService.decryptMessage(
        messageData: messageData,
        currentUserId: 'bob_uid',
        currentUserPrivateKey: bobKeys['privateKey']!,
      );
      
      expect(bobDecrypted, equals(originalMessage));
      print('✓ Bob (recipient) can read the message: $bobDecrypted');
      
      print('✅ TEST 9 PASSED: Recipient can read messages');
    });
    
    test('✅ TEST 10: Third Party Cannot Read Messages', () {
      print('\n--- TEST 10: Third Party Cannot Read Messages ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      final eveKeys = MockEncryptionService.generateRSAKeyPair(); // Eve is eavesdropper
      
      MockEncryptedChatService.setUserPublicKey('alice_uid', aliceKeys['publicKey']!);
      MockEncryptedChatService.setUserPublicKey('bob_uid', bobKeys['publicKey']!);
      MockEncryptedChatService.setUserPublicKey('eve_uid', eveKeys['publicKey']!);
      
      final secretMessage = 'This is a secret between Alice and Bob!';
      
      // Alice sends message to Bob
      final messageData = MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid',
        message: secretMessage,
        senderPublicKey: aliceKeys['publicKey']!,
      )!;
      
      // Eve tries to decrypt the message
      final eveDecrypted = MockEncryptedChatService.decryptMessage(
        messageData: messageData,
        currentUserId: 'eve_uid',
        currentUserPrivateKey: eveKeys['privateKey']!,
      );
      
      expect(eveDecrypted, equals('[Decryption Error: Unable to decrypt message]'));
      print('✓ Eve (third party) cannot read the message: $eveDecrypted');
      
      print('✅ TEST 10 PASSED: Third party cannot read messages');
    });
    
    test('✅ TEST 11: Unencrypted Message Fallback', () {
      print('\n--- TEST 11: Unencrypted Message Fallback ---');
      
      final unencryptedMessage = {
        'sendBy': 'Alice',
        'senderUid': 'alice_uid',
        'message': 'This is a plain text message',
        'encrypted': false,
        'type': 'text',
      };
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      
      final decrypted = MockEncryptedChatService.decryptMessage(
        messageData: unencryptedMessage,
        currentUserId: 'bob_uid',
        currentUserPrivateKey: aliceKeys['privateKey']!,
      );
      
      expect(decrypted, equals('This is a plain text message'));
      print('✓ Unencrypted message returned as-is: $decrypted');
      
      print('✅ TEST 11 PASSED: Unencrypted message fallback works');
    });
    
    test('✅ TEST 12: No Public Key Returns Null', () {
      print('\n--- TEST 12: No Public Key Returns Null ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      MockEncryptedChatService.setUserPublicKey('alice_uid', aliceKeys['publicKey']!);
      // Note: Bob's public key is NOT registered
      
      final messageData = MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid', // Bob has no public key
        message: 'Hello Bob!',
        senderPublicKey: aliceKeys['publicKey']!,
      );
      
      expect(messageData, isNull);
      print('✓ Cannot encrypt when recipient has no public key');
      
      print('✅ TEST 12 PASSED: Missing public key handled correctly');
    });
    
    test('✅ TEST 13: Full Chat Conversation Flow', () {
      print('\n--- TEST 13: Full Chat Conversation Flow ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockEncryptedChatService.setUserPublicKey('alice_uid', aliceKeys['publicKey']!);
      MockEncryptedChatService.setUserPublicKey('bob_uid', bobKeys['publicKey']!);
      
      final conversation = <Map<String, dynamic>>[];
      
      // Alice sends to Bob
      conversation.add(MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid',
        message: 'Hi Bob! How are you? 👋',
        senderPublicKey: aliceKeys['publicKey']!,
      )!);
      
      // Bob sends to Alice
      conversation.add(MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'bob_uid',
        senderName: 'Bob',
        recipientId: 'alice_uid',
        message: 'Hey Alice! I\'m doing great! 😊',
        senderPublicKey: bobKeys['publicKey']!,
      )!);
      
      // Alice sends another message
      conversation.add(MockEncryptedChatService.sendEncryptedMessage(
        senderId: 'alice_uid',
        senderName: 'Alice',
        recipientId: 'bob_uid',
        message: 'Let\'s meet tomorrow? 📅',
        senderPublicKey: aliceKeys['publicKey']!,
      )!);
      
      print('✓ Conversation with ${conversation.length} messages created');
      
      // Verify Alice can read all messages
      print('\n📱 Alice\'s view:');
      for (final msg in conversation) {
        final decrypted = MockEncryptedChatService.decryptMessage(
          messageData: msg,
          currentUserId: 'alice_uid',
          currentUserPrivateKey: aliceKeys['privateKey']!,
        );
        print('  ${msg['sendBy']}: $decrypted');
        expect(decrypted.contains('[Decryption Error'), false);
      }
      
      // Verify Bob can read all messages
      print('\n📱 Bob\'s view:');
      for (final msg in conversation) {
        final decrypted = MockEncryptedChatService.decryptMessage(
          messageData: msg,
          currentUserId: 'bob_uid',
          currentUserPrivateKey: bobKeys['privateKey']!,
        );
        print('  ${msg['sendBy']}: $decrypted');
        expect(decrypted.contains('[Decryption Error'), false);
      }
      
      print('\n✅ TEST 13 PASSED: Full conversation flow works correctly');
    });
  });
  
  group('🔒 Security Edge Cases', () {
    test('✅ TEST 14: Empty Message Handling', () {
      print('\n--- TEST 14: Empty Message Handling ---');
      
      final keyPair = MockEncryptionService.generateRSAKeyPair();
      
      final encryptedData = MockEncryptionService.encryptMessage(
        '',
        keyPair['publicKey']!,
      );
      
      final decrypted = MockEncryptionService.decryptMessage(
        encryptedData,
        keyPair['privateKey']!,
      );
      
      expect(decrypted, equals(''));
      print('✓ Empty message encrypted and decrypted correctly');
      
      print('✅ TEST 14 PASSED: Empty message handling works');
    });
    
    test('✅ TEST 15: Special Characters Handling', () {
      print('\n--- TEST 15: Special Characters Handling ---');
      
      final keyPair = MockEncryptionService.generateRSAKeyPair();
      final specialMessage = r'Special chars: \n \t \r \\ "quotes" ' + "'apostrophe' <xml> &amp;";
      
      final encryptedData = MockEncryptionService.encryptMessage(
        specialMessage,
        keyPair['publicKey']!,
      );
      
      final decrypted = MockEncryptionService.decryptMessage(
        encryptedData,
        keyPair['privateKey']!,
      );
      
      expect(decrypted, equals(specialMessage));
      print('✓ Special characters handled correctly');
      print('✓ Original: $specialMessage');
      print('✓ Decrypted: $decrypted');
      
      print('✅ TEST 15 PASSED: Special characters handling works');
    });
  });
}
