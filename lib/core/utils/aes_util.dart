import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

/// AES-256 CBC encryption/decryption utility using PointyCastle.
///
/// Provides secure file encryption for the Private Vault feature.
abstract final class AesUtil {
  /// Generates a random AES-256 key.
  static Uint8List generateKey() {
    final random = SecureRandom('Fortuna')
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List<int>.generate(32, (_) => Random.secure().nextInt(256)),
          ),
        ),
      );
    return random.nextBytes(AppConstants.aesKeyLength ~/ 8);
  }

  /// Generates a random initialization vector (IV).
  static Uint8List generateIv() {
    final random = SecureRandom('Fortuna')
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List<int>.generate(32, (_) => Random.secure().nextInt(256)),
          ),
        ),
      );
    return random.nextBytes(AppConstants.aesIvLength);
  }

  /// Encrypts [plainData] using AES-256-CBC with [key] and [iv].
  ///
  /// Returns the encrypted bytes. Applies PKCS7 padding automatically.
  static Uint8List encrypt({
    required Uint8List plainData,
    required Uint8List key,
    required Uint8List iv,
  }) {
    try {
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          true,
          PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
            ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
            null,
          ),
        );
      return cipher.process(plainData);
    } catch (e) {
      throw CryptoException(message: 'Encryption failed: $e');
    }
  }

  /// Decrypts [encryptedData] using AES-256-CBC with [key] and [iv].
  ///
  /// Returns the decrypted bytes. Removes PKCS7 padding automatically.
  static Uint8List decrypt({
    required Uint8List encryptedData,
    required Uint8List key,
    required Uint8List iv,
  }) {
    try {
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
            ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
            null,
          ),
        );
      return cipher.process(encryptedData);
    } catch (e) {
      throw CryptoException(message: 'Decryption failed: $e');
    }
  }

  /// Derives a key from [password] using PBKDF2 with SHA-256.
  ///
  /// [salt] should be unique per user/vault.
  /// [iterations] defaults to 100,000 for security.
  static Uint8List deriveKey({
    required String password,
    required Uint8List salt,
    int iterations = 100000,
  }) {
    try {
      final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(salt, iterations, 32));
      return derivator.process(Uint8List.fromList(password.codeUnits));
    } catch (e) {
      throw CryptoException(message: 'Key derivation failed: $e');
    }
  }
}
