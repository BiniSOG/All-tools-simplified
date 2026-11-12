import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Encryption used by the File Locker: AES-256-GCM with a key stretched from the PIN.
/// Kept free of Flutter and plugins so it can be unit-tested.
class LockerCrypto {
  static final _aes = AesGcm.with256bits();

  /// Turns a PIN into a key. [iterations] slows down guessing; lower it only in tests.
  static Future<SecretKey> deriveKey(String pin, List<int> salt, {int iterations = 20000}) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256).deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);

  /// Returns nonce + ciphertext + authentication tag as one block.
  static Future<Uint8List> encrypt(List<int> data, SecretKey key) async => (await _aes.encrypt(data, secretKey: key)).concatenation();

  /// Returns the original bytes, or null if the key is wrong or the data was altered.
  static Future<List<int>?> decrypt(Uint8List blob, SecretKey key) async {
    try {
      return await _aes.decrypt(
        SecretBox.fromConcatenation(blob, nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      return null;
    } catch (_) {
      return null;
    }
  }
}
