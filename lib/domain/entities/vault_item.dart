import 'package:equatable/equatable.dart';

/// Represents an encrypted file stored in the Private Vault.
class VaultItem extends Equatable {
  final String id;
  final String originalName;
  final String encryptedPath;
  final String originalPath;
  final int originalSize;
  final String mimeType;
  final DateTime encryptedAt;
  final bool isLocked;

  const VaultItem({
    required this.id,
    required this.originalName,
    required this.encryptedPath,
    required this.originalPath,
    required this.originalSize,
    required this.mimeType,
    required this.encryptedAt,
    this.isLocked = true,
  });

  @override
  List<Object?> get props => [id, encryptedPath];
}
