import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// End-to-End Encryption Service using RSA + AES
/// 
/// Workflow:
/// 1. Each user has RSA key pair (public/private)
/// 2. Messages are encrypted with AES (symmetric)
/// 3. AES key is encrypted with recipient's RSA public key
/// 4. Only recipient's RSA private key can decrypt the AES key
class EncryptionService {
  
  /// Generate RSA Key Pair for a user
  /// Returns: {publicKey: String, privateKey: String}
  static Map<String, String> generateRSAKeyPair() {
    final keyGen = RSAKeyGenerator();
    
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    
    final params = RSAKeyGeneratorParameters(
      BigInt.parse('65537'), // public exponent
      2048, // key size in bits
      64, // certainty for prime generation
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
  
  /// Encrypt a message for a specific recipient
  /// 
  /// Parameters:
  /// - message: Plain text message to encrypt
  /// - recipientPublicKey: Recipient's RSA public key (PEM format)
  /// 
  /// Returns: Encrypted message object with:
  ///   - encryptedMessage: AES encrypted message (base64)
  ///   - encryptedAESKey: RSA encrypted AES key (base64)
  ///   - iv: Initialization Vector (base64)
  static Map<String, String> encryptMessage(
    String message,
    String recipientPublicKey,
  ) {
    // Handle empty message edge case
    final messageToEncrypt = message.isEmpty ? ' ' : message;
    
    // Generate random AES key (256-bit)
    final aesKey = encrypt_pkg.Key.fromSecureRandom(32);
    
    // Generate random IV
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    
    // Encrypt message with AES
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(aesKey, mode: encrypt_pkg.AESMode.cbc),
    );
    final encryptedMessage = encrypter.encrypt(messageToEncrypt, iv: iv);
    
    // Encrypt AES key with recipient's RSA public key
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
  
  /// Decrypt a message using private key
  /// 
  /// Parameters:
  /// - encryptedData: Map containing encryptedMessage, encryptedAESKey, iv
  /// - privateKey: User's RSA private key (PEM format)
  /// 
  /// Returns: Decrypted plain text message
  static String decryptMessage(
    Map<String, String> encryptedData,
    String privateKey,
  ) {
    try {
      // Parse encrypted data
      final encryptedMessage = encrypt_pkg.Encrypted.fromBase64(
        encryptedData['encryptedMessage']!,
      );
      final encryptedAESKey = encrypt_pkg.Encrypted.fromBase64(
        encryptedData['encryptedAESKey']!,
      );
      final iv = encrypt_pkg.IV.fromBase64(encryptedData['iv']!);
      
      // Decrypt AES key with RSA private key
      final rsaPrivateKey = _parsePrivateKeyFromPem(privateKey);
      final rsaEncrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.RSA(privateKey: rsaPrivateKey),
      );
      final aesKeyBytes = rsaEncrypter.decryptBytes(encryptedAESKey);
      final aesKey = encrypt_pkg.Key(Uint8List.fromList(aesKeyBytes));
      
      // Decrypt message with AES key
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(aesKey, mode: encrypt_pkg.AESMode.cbc),
      );
      final decryptedMessage = encrypter.decrypt(encryptedMessage, iv: iv);
      
      // Handle empty message edge case (we encrypted ' ' for empty messages)
      return decryptedMessage.trim().isEmpty ? '' : decryptedMessage;
    } catch (e) {
      return '[Decryption Error: Unable to decrypt message]';
    }
  }
  
  /// Generate a secure hash of data (for verification)
  static String generateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // ===== Private Helper Methods =====
  
  static String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final modulus = _encodeBigInt(publicKey.modulus!);
    final exponent = _encodeBigInt(publicKey.exponent!);
    
    final keyData = {
      'modulus': modulus,
      'exponent': exponent,
    };
    
    return base64.encode(utf8.encode(json.encode(keyData)));
  }
  
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final modulus = _encodeBigInt(privateKey.modulus!);
    final exponent = _encodeBigInt(privateKey.exponent!);
    final p = _encodeBigInt(privateKey.p!);
    final q = _encodeBigInt(privateKey.q!);
    
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
    final modulus = _decodeBigInt(keyData['modulus']);
    final exponent = _decodeBigInt(keyData['exponent']);
    
    return RSAPublicKey(modulus, exponent);
  }
  
  static RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final keyData = json.decode(utf8.decode(base64.decode(pem)));
    final modulus = _decodeBigInt(keyData['modulus']);
    final exponent = _decodeBigInt(keyData['exponent']);
    final p = _decodeBigInt(keyData['p']);
    final q = _decodeBigInt(keyData['q']);
    
    return RSAPrivateKey(modulus, exponent, p, q);
  }
  
  static String _encodeBigInt(BigInt number) {
    return number.toString();
  }
  
  static BigInt _decodeBigInt(String encoded) {
    return BigInt.parse(encoded);
  }
}
