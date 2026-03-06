import '../entities/vault_item.dart';

/// Abstract repository contract for the Private Vault.
abstract class VaultRepository {
  /// Encrypts a file and adds it to the vault.
  Future<VaultItem> encryptAndStore(String filePath);

  /// Decrypts a file from the vault to a temporary location.
  Future<String> decryptFile(String vaultItemId);

  /// Gets all vault items.
  Future<List<VaultItem>> getAllVaultItems();

  /// Deletes a vault item (removes encrypted file).
  Future<void> deleteVaultItem(String vaultItemId);

  /// Authenticates using biometrics before vault access.
  Future<bool> authenticateVault();

  /// Checks if biometric authentication is available.
  Future<bool> isBiometricAvailable();

  /// Locks the vault (clears session).
  Future<void> lockVault();
}
