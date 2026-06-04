import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EncryptionService {
  // Generate a shared key for a chat between two users (end-to-end, same for both users)
  static encrypt.Key getSharedKey(String uid1, String uid2) {
    final users = [uid1, uid2]..sort();
    final combined = users.join('_secure_chat_');
    final keyBytes = sha256.convert(utf8.encode(combined)).bytes;
    return encrypt.Key(Uint8List.fromList(keyBytes));
  }

  // Generate a group key for group chats
  static encrypt.Key getGroupKey(String groupId) {
    final combined = '${groupId}_group_secure_chat_key';
    final keyBytes = sha256.convert(utf8.encode(combined)).bytes;
    return encrypt.Key(Uint8List.fromList(keyBytes));
  }

  static String encryptText(String plainText, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decryptText(String combined, encrypt.Key key) {
    try {
      final parts = combined.split(':');
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return '🔒 Unable to decrypt';
    }
  }

  static Uint8List encryptFile(Uint8List fileBytes, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
    // Prepend IV to encrypted bytes for later decryption
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setRange(0, iv.bytes.length, iv.bytes);
    result.setRange(iv.bytes.length, result.length, encrypted.bytes);
    return result;
  }

  static Uint8List decryptFile(Uint8List encryptedBytes, encrypt.Key key) {
    // Extract IV (first 16 bytes)
    final iv = encrypt.IV(encryptedBytes.sublist(0, 16));
    final encrypted = encrypt.Encrypted(encryptedBytes.sublist(16));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return Uint8List.fromList(decrypted);
  }
}