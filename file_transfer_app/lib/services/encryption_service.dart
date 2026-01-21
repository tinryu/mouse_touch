import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Service for encryption and security
class EncryptionService {
  /// Generate AES key from password
  encrypt.Key generateAESKey(String password) {
    // Use SHA-256 to generate 256-bit key from password
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// Generate random IV (Initialization Vector)
  encrypt.IV generateIV() {
    return encrypt.IV.fromSecureRandom(16);
  }

  /// Encrypt data with AES
  String encryptAES(String plainText, encrypt.Key key, encrypt.IV iv) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// Decrypt data with AES
  String decryptAES(String encryptedText, encrypt.Key key, encrypt.IV iv) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
    return decrypted;
  }

  /// Calculate SHA-256 hash of a file
  Future<String> calculateFileHash(List<int> fileBytes) async {
    return sha256.convert(fileBytes).toString();
  }

  /// Generate device ID hash
  String generateDeviceHash(String deviceId) {
    final bytes = utf8.encode(deviceId);
    return sha256.convert(bytes).toString();
  }

  /// Verify password
  bool verifyPassword(String password, String hashedPassword) {
    final hash = sha256.convert(utf8.encode(password)).toString();
    return hash == hashedPassword;
  }
}
