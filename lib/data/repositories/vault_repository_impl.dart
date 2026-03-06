import 'dart:io';
import 'dart:typed_data';

import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../core/utils/aes_util.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/vault_item.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasources/local/vault_local_datasource.dart';

/// Implementation of [VaultRepository] with AES-256 encryption and biometric auth.
class VaultRepositoryImpl implements VaultRepository {
  final VaultLocalDatasource _localDatasource;
  final LocalAuthentication _localAuth;
  final _uuid = const Uuid();

  bool _isUnlocked = false;

  // In production, this would be derived from user's biometric key or password
  late final Uint8List _encryptionKey;
  late final Uint8List _iv;

  VaultRepositoryImpl({
    required VaultLocalDatasource localDatasource,
    LocalAuthentication? localAuth,
  })  : _localDatasource = localDatasource,
        _localAuth = localAuth ?? LocalAuthentication() {
    // Initialize with a derived key (in production, use PBKDF2 from user secret)
    _encryptionKey = AesUtil.generateKey();
    _iv = AesUtil.generateIv();
  }

  @override
  Future<VaultItem> encryptAndStore(String filePath) async {
    if (!_isUnlocked) {
      throw const CryptoException(message: 'Vault is locked');
    }

    try {
      final file = File(filePath);
      final plainData = await file.readAsBytes();

      // Encrypt
      final encryptedData = AesUtil.encrypt(
        plainData: plainData,
        key: _encryptionKey,
        iv: _iv,
      );

      // Store encrypted file
      final vaultDir = await _getVaultDirectory();
      final vaultId = _uuid.v4();
      final encryptedPath = '${vaultDir.path}/$vaultId.enc';

      await File(encryptedPath).writeAsBytes(encryptedData);

      final item = VaultItem(
        id: vaultId,
        originalName: FileUtils.getFileName(filePath),
        encryptedPath: encryptedPath,
        originalPath: filePath,
        originalSize: plainData.length,
        mimeType: FileUtils.getMimeType(filePath),
        encryptedAt: DateTime.now(),
      );

      // Persist metadata
      await _localDatasource.insertVaultItem({
        'id': item.id,
        'original_name': item.originalName,
        'encrypted_path': item.encryptedPath,
        'original_path': item.originalPath,
        'original_size': item.originalSize,
        'mime_type': item.mimeType,
        'encrypted_at': item.encryptedAt.toIso8601String(),
        'is_locked': 1,
      });

      return item;
    } catch (e) {
      if (e is CryptoException) rethrow;
      throw CryptoException(message: 'Failed to encrypt file: $e');
    }
  }

  @override
  Future<String> decryptFile(String vaultItemId) async {
    if (!_isUnlocked) {
      throw const CryptoException(message: 'Vault is locked');
    }

    try {
      final itemData = await _localDatasource.getVaultItemById(vaultItemId);
      if (itemData == null) {
        throw const CryptoException(message: 'Vault item not found');
      }

      final encryptedFile = File(itemData['encrypted_path'] as String);
      final encryptedData = await encryptedFile.readAsBytes();

      final decryptedData = AesUtil.decrypt(
        encryptedData: encryptedData,
        key: _encryptionKey,
        iv: _iv,
      );

      // Write to temporary location
      final tempDir = await getTemporaryDirectory();
      final originalName = itemData['original_name'] as String;
      final tempPath = '${tempDir.path}/$originalName';
      await File(tempPath).writeAsBytes(decryptedData);

      return tempPath;
    } catch (e) {
      if (e is CryptoException) rethrow;
      throw CryptoException(message: 'Failed to decrypt file: $e');
    }
  }

  @override
  Future<List<VaultItem>> getAllVaultItems() async {
    final items = await _localDatasource.getAllVaultItems();
    return items.map((data) {
      return VaultItem(
        id: data['id'] as String,
        originalName: data['original_name'] as String,
        encryptedPath: data['encrypted_path'] as String,
        originalPath: data['original_path'] as String,
        originalSize: data['original_size'] as int,
        mimeType: data['mime_type'] as String,
        encryptedAt: DateTime.parse(data['encrypted_at'] as String),
        isLocked: (data['is_locked'] as int) == 1,
      );
    }).toList();
  }

  @override
  Future<void> deleteVaultItem(String vaultItemId) async {
    final itemData = await _localDatasource.getVaultItemById(vaultItemId);
    if (itemData != null) {
      final encryptedFile = File(itemData['encrypted_path'] as String);
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
    }
    await _localDatasource.deleteVaultItem(vaultItemId);
  }

  @override
  Future<bool> authenticateVault() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Private Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      _isUnlocked = authenticated;
      return authenticated;
    } catch (e) {
      _isUnlocked = false;
      return false;
    }
  }

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuth || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> lockVault() async {
    _isUnlocked = false;
  }

  Future<Directory> _getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }
}
