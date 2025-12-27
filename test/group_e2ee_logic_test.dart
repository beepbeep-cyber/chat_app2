import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:pointycastle/export.dart';

/// Test file for Group E2EE (End-to-End Encryption) logic
/// Tests RSA+AES encryption workflow for group chats

// ==================== MOCK ENCRYPTION SERVICE ====================
class MockEncryptionService {
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
  
  static String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final modulus = publicKey.modulus!.toString();
    final exponent = publicKey.exponent!.toString();
    final keyData = {'modulus': modulus, 'exponent': exponent};
    return base64.encode(utf8.encode(json.encode(keyData)));
  }
  
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final keyData = {
      'modulus': privateKey.modulus!.toString(),
      'exponent': privateKey.exponent!.toString(),
      'p': privateKey.p!.toString(),
      'q': privateKey.q!.toString(),
    };
    return base64.encode(utf8.encode(json.encode(keyData)));
  }
  
  static RSAPublicKey _parsePublicKeyFromPem(String pem) {
    final keyData = json.decode(utf8.decode(base64.decode(pem)));
    return RSAPublicKey(BigInt.parse(keyData['modulus']), BigInt.parse(keyData['exponent']));
  }
  
  static RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final keyData = json.decode(utf8.decode(base64.decode(pem)));
    return RSAPrivateKey(
      BigInt.parse(keyData['modulus']),
      BigInt.parse(keyData['exponent']),
      BigInt.parse(keyData['p']),
      BigInt.parse(keyData['q']),
    );
  }
}

// ==================== MOCK GROUP ENCRYPTION SERVICE ====================
class MockGroupEncryptionService {
  // Simulate user keys storage
  static final Map<String, Map<String, String>> _userKeys = {}; // userId -> {publicKey, privateKey}
  
  static void registerUser(String userId, Map<String, String> keyPair) {
    _userKeys[userId] = keyPair;
  }
  
  static String? getUserPublicKey(String userId) {
    return _userKeys[userId]?['publicKey'];
  }
  
  static String? getUserPrivateKey(String userId) {
    return _userKeys[userId]?['privateKey'];
  }
  
  static void clearUsers() {
    _userKeys.clear();
  }
  
  /// Encrypt a message for all group members
  /// Returns JSON string with encrypted versions for each member
  static String? encryptGroupMessage(String message, List<String> memberIds) {
    if (memberIds.isEmpty) return null;
    
    Map<String, Map<String, String>> encryptedForMembers = {};
    
    for (var memberId in memberIds) {
      final publicKey = getUserPublicKey(memberId);
      if (publicKey != null) {
        final encryptedData = MockEncryptionService.encryptMessage(message, publicKey);
        encryptedForMembers[memberId] = encryptedData;
      }
    }
    
    if (encryptedForMembers.isEmpty) return null;
    
    return json.encode(encryptedForMembers);
  }
  
  /// Decrypt a group message for a specific user
  static String? decryptGroupMessage(String encryptedMessage, String userId) {
    try {
      final privateKey = getUserPrivateKey(userId);
      if (privateKey == null) return '[Private key not found]';
      
      Map<String, dynamic> encryptedForMembers = json.decode(encryptedMessage);
      
      final userEncryptedData = encryptedForMembers[userId];
      if (userEncryptedData == null) return '[No encrypted data for current user]';
      
      Map<String, String> encryptedData = Map<String, String>.from(userEncryptedData);
      
      return MockEncryptionService.decryptMessage(encryptedData, privateKey);
    } catch (e) {
      return '[Decryption error]';
    }
  }
  
  /// Check if message is encrypted
  static bool isEncrypted(String message) {
    try {
      final decoded = json.decode(message);
      return decoded is Map && decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

// ==================== TEST CASES ====================
void main() {
  setUp(() {
    MockGroupEncryptionService.clearUsers();
  });

  group('👥 GroupEncryptionService Tests', () {
    test('✅ TEST 1: Encrypt Message for Multiple Group Members', () {
      print('\n--- TEST 1: Encrypt Message for Multiple Group Members ---');
      
      // Create 4 group members
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      final charlieKeys = MockEncryptionService.generateRSAKeyPair();
      final daveKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      MockGroupEncryptionService.registerUser('bob_uid', bobKeys);
      MockGroupEncryptionService.registerUser('charlie_uid', charlieKeys);
      MockGroupEncryptionService.registerUser('dave_uid', daveKeys);
      
      final memberIds = ['alice_uid', 'bob_uid', 'charlie_uid', 'dave_uid'];
      final message = 'Hello Group! 🎉';
      
      // Encrypt message for all members
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(message, memberIds);
      
      expect(encryptedJson, isNotNull);
      
      // Verify JSON structure
      final decoded = json.decode(encryptedJson!);
      expect(decoded.length, equals(4));
      expect(decoded.containsKey('alice_uid'), true);
      expect(decoded.containsKey('bob_uid'), true);
      expect(decoded.containsKey('charlie_uid'), true);
      expect(decoded.containsKey('dave_uid'), true);
      
      print('✓ Message encrypted for ${decoded.length} members');
      print('✓ JSON structure contains all member IDs');
      print('✅ TEST 1 PASSED: Group message encryption works');
    });
    
    test('✅ TEST 2: All Group Members Can Decrypt Message', () {
      print('\n--- TEST 2: All Group Members Can Decrypt Message ---');
      
      // Create group members
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      final charlieKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      MockGroupEncryptionService.registerUser('bob_uid', bobKeys);
      MockGroupEncryptionService.registerUser('charlie_uid', charlieKeys);
      
      final memberIds = ['alice_uid', 'bob_uid', 'charlie_uid'];
      final originalMessage = 'This is a secret group message! 🔐';
      
      // Encrypt
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        originalMessage, 
        memberIds,
      )!;
      
      // Each member decrypts
      for (var memberId in memberIds) {
        final decrypted = MockGroupEncryptionService.decryptGroupMessage(
          encryptedJson, 
          memberId,
        );
        expect(decrypted, equals(originalMessage));
        print('✓ $memberId decrypted: "$decrypted"');
      }
      
      print('✅ TEST 2 PASSED: All group members can decrypt');
    });
    
    test('✅ TEST 3: Non-Member Cannot Decrypt Group Message', () {
      print('\n--- TEST 3: Non-Member Cannot Decrypt Group Message ---');
      
      // Create group members
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      final eveKeys = MockEncryptionService.generateRSAKeyPair(); // Eve is NOT a member
      
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      MockGroupEncryptionService.registerUser('bob_uid', bobKeys);
      MockGroupEncryptionService.registerUser('eve_uid', eveKeys); // Eve has keys but not in group
      
      final memberIds = ['alice_uid', 'bob_uid']; // Eve NOT included
      final secretMessage = 'Secret group message - Eve should NOT see this!';
      
      // Encrypt ONLY for Alice and Bob
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        secretMessage, 
        memberIds,
      )!;
      
      // Eve tries to decrypt
      final eveDecrypted = MockGroupEncryptionService.decryptGroupMessage(
        encryptedJson, 
        'eve_uid',
      );
      
      expect(eveDecrypted, equals('[No encrypted data for current user]'));
      print('✓ Eve (non-member) cannot decrypt: "$eveDecrypted"');
      
      // Alice can still decrypt
      final aliceDecrypted = MockGroupEncryptionService.decryptGroupMessage(
        encryptedJson, 
        'alice_uid',
      );
      expect(aliceDecrypted, equals(secretMessage));
      print('✓ Alice (member) can decrypt: "$aliceDecrypted"');
      
      print('✅ TEST 3 PASSED: Non-members cannot decrypt group messages');
    });
    
    test('✅ TEST 4: Group Message with Unicode and Emoji', () {
      print('\n--- TEST 4: Group Message with Unicode and Emoji ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      MockGroupEncryptionService.registerUser('bob_uid', bobKeys);
      
      final messages = [
        'Hello Nhóm! 🇻🇳',
        'Xin chào các bạn! 👋',
        '日本語テスト 🎌',
        '🔐💬👥🎉✨',
      ];
      
      for (var message in messages) {
        final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
          message, 
          ['alice_uid', 'bob_uid'],
        )!;
        
        final aliceDecrypted = MockGroupEncryptionService.decryptGroupMessage(
          encryptedJson, 
          'alice_uid',
        );
        final bobDecrypted = MockGroupEncryptionService.decryptGroupMessage(
          encryptedJson, 
          'bob_uid',
        );
        
        expect(aliceDecrypted, equals(message));
        expect(bobDecrypted, equals(message));
        print('✓ "$message" → Alice: "$aliceDecrypted" | Bob: "$bobDecrypted"');
      }
      
      print('✅ TEST 4 PASSED: Unicode and emoji support works');
    });
    
    test('✅ TEST 5: Large Group (10 Members)', () {
      print('\n--- TEST 5: Large Group (10 Members) ---');
      
      final memberIds = <String>[];
      
      // Create 10 members
      for (var i = 1; i <= 10; i++) {
        final userId = 'user_$i';
        final keys = MockEncryptionService.generateRSAKeyPair();
        MockGroupEncryptionService.registerUser(userId, keys);
        memberIds.add(userId);
      }
      
      print('✓ Created ${memberIds.length} group members');
      
      final message = 'Message to all 10 members! 🔐';
      
      // Encrypt for all members
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        message, 
        memberIds,
      )!;
      
      // Verify JSON structure
      final decoded = json.decode(encryptedJson);
      expect(decoded.length, equals(10));
      print('✓ Encrypted JSON contains ${decoded.length} member entries');
      
      // Each member decrypts
      for (var memberId in memberIds) {
        final decrypted = MockGroupEncryptionService.decryptGroupMessage(
          encryptedJson, 
          memberId,
        );
        expect(decrypted, equals(message));
      }
      
      print('✓ All 10 members successfully decrypted the message');
      print('✅ TEST 5 PASSED: Large group encryption works');
    });
    
    test('✅ TEST 6: isEncrypted Detection', () {
      print('\n--- TEST 6: isEncrypted Detection ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      
      // Encrypted message
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        'Test message', 
        ['alice_uid'],
      )!;
      
      expect(MockGroupEncryptionService.isEncrypted(encryptedJson), true);
      print('✓ Encrypted JSON detected as encrypted: true');
      
      // Plain text
      expect(MockGroupEncryptionService.isEncrypted('Hello World'), false);
      print('✓ Plain text detected as encrypted: false');
      
      // Invalid JSON
      expect(MockGroupEncryptionService.isEncrypted('{invalid'), false);
      print('✓ Invalid JSON detected as encrypted: false');
      
      // Empty object
      expect(MockGroupEncryptionService.isEncrypted('{}'), false);
      print('✓ Empty object detected as encrypted: false');
      
      print('✅ TEST 6 PASSED: isEncrypted detection works');
    });
    
    test('✅ TEST 7: Full Group Conversation Flow', () {
      print('\n--- TEST 7: Full Group Conversation Flow ---');
      
      // Create group members
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      final bobKeys = MockEncryptionService.generateRSAKeyPair();
      final charlieKeys = MockEncryptionService.generateRSAKeyPair();
      
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      MockGroupEncryptionService.registerUser('bob_uid', bobKeys);
      MockGroupEncryptionService.registerUser('charlie_uid', charlieKeys);
      
      final memberIds = ['alice_uid', 'bob_uid', 'charlie_uid'];
      
      // Simulate conversation
      final conversation = <Map<String, dynamic>>[];
      
      // Alice sends a message
      var encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        'Hi everyone! 👋', 
        memberIds,
      )!;
      conversation.add({
        'sendBy': 'Alice',
        'senderId': 'alice_uid',
        'message': encryptedJson,
        'isEncrypted': true,
      });
      
      // Bob replies
      encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        'Hey Alice! How are you? 😊', 
        memberIds,
      )!;
      conversation.add({
        'sendBy': 'Bob',
        'senderId': 'bob_uid',
        'message': encryptedJson,
        'isEncrypted': true,
      });
      
      // Charlie replies
      encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        'Hello team! 🎉', 
        memberIds,
      )!;
      conversation.add({
        'sendBy': 'Charlie',
        'senderId': 'charlie_uid',
        'message': encryptedJson,
        'isEncrypted': true,
      });
      
      print('✓ Conversation with ${conversation.length} messages created');
      
      // Each member views the conversation
      for (var viewerId in memberIds) {
        print('\n📱 ${viewerId.replaceAll('_uid', '').toUpperCase()}\'s view:');
        for (var msg in conversation) {
          final decrypted = MockGroupEncryptionService.decryptGroupMessage(
            msg['message'], 
            viewerId,
          );
          print('  ${msg['sendBy']}: $decrypted');
          expect(decrypted!.contains('['), false);
        }
      }
      
      print('\n✅ TEST 7 PASSED: Full group conversation flow works');
    });
    
    test('✅ TEST 8: Empty Member List Returns Null', () {
      print('\n--- TEST 8: Empty Member List Returns Null ---');
      
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        'Test message', 
        [], // Empty member list
      );
      
      expect(encryptedJson, isNull);
      print('✓ Empty member list returns null');
      
      print('✅ TEST 8 PASSED: Empty member list handled correctly');
    });
    
    test('✅ TEST 9: Member Without Keys is Skipped', () {
      print('\n--- TEST 9: Member Without Keys is Skipped ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      // bob_uid is NOT registered (has no keys)
      
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        'Test message', 
        ['alice_uid', 'bob_uid'], // Bob has no keys
      )!;
      
      final decoded = json.decode(encryptedJson);
      expect(decoded.length, equals(1)); // Only Alice
      expect(decoded.containsKey('alice_uid'), true);
      expect(decoded.containsKey('bob_uid'), false);
      
      print('✓ Only Alice (with keys) has encrypted data');
      print('✓ Bob (without keys) is skipped');
      
      // Alice can still decrypt
      final aliceDecrypted = MockGroupEncryptionService.decryptGroupMessage(
        encryptedJson, 
        'alice_uid',
      );
      expect(aliceDecrypted, equals('Test message'));
      print('✓ Alice can decrypt: "$aliceDecrypted"');
      
      print('✅ TEST 9 PASSED: Members without keys are skipped');
    });
    
    test('✅ TEST 10: Empty Message Handling', () {
      print('\n--- TEST 10: Empty Message Handling ---');
      
      final aliceKeys = MockEncryptionService.generateRSAKeyPair();
      MockGroupEncryptionService.registerUser('alice_uid', aliceKeys);
      
      final encryptedJson = MockGroupEncryptionService.encryptGroupMessage(
        '', // Empty message
        ['alice_uid'],
      )!;
      
      final decrypted = MockGroupEncryptionService.decryptGroupMessage(
        encryptedJson, 
        'alice_uid',
      );
      
      expect(decrypted, equals(''));
      print('✓ Empty message encrypted and decrypted correctly');
      
      print('✅ TEST 10 PASSED: Empty message handling works');
    });
  });
}
