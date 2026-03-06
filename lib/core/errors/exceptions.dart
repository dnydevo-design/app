/// Custom exception classes for the data layer.
library;

/// Thrown when the shelf server encounters an error.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown when a network connection fails or drops.
class ConnectionException implements Exception {
  final String message;
  const ConnectionException({required this.message});

  @override
  String toString() => 'ConnectionException: $message';
}

/// Thrown when a database operation fails.
class DatabaseException implements Exception {
  final String message;
  const DatabaseException({required this.message});

  @override
  String toString() => 'DatabaseException: $message';
}

/// Thrown when a file read/write operation fails.
class FileIOException implements Exception {
  final String message;
  const FileIOException({required this.message});

  @override
  String toString() => 'FileIOException: $message';
}

/// Thrown when a CRC32 checksum does not match.
class ChecksumMismatchException implements Exception {
  final int expected;
  final int actual;
  const ChecksumMismatchException({
    required this.expected,
    required this.actual,
  });

  @override
  String toString() =>
      'ChecksumMismatchException: expected=$expected, actual=$actual';
}

/// Thrown when an encryption or decryption operation fails.
class CryptoException implements Exception {
  final String message;
  const CryptoException({required this.message});

  @override
  String toString() => 'CryptoException: $message';
}

/// Thrown when a required permission is not granted.
class PermissionDeniedException implements Exception {
  final String permission;
  const PermissionDeniedException({required this.permission});

  @override
  String toString() => 'PermissionDeniedException: $permission';
}
