/// Application-wide constants for Fast Share.
library;

/// Core configuration constants.
abstract final class AppConstants {
  /// Default chunk size for file splitting: 2 MB.
  static const int chunkSize = 2 * 1024 * 1024;

  /// Default server port for shelf HTTP server.
  static const int serverPort = 8642;

  /// Default discovery broadcast port.
  static const int discoveryPort = 8643;

  /// Default streaming port.
  static const int streamPort = 8644;

  /// Maximum concurrent connections for 1-to-N.
  static const int maxConnections = 20;

  /// Connection timeout in seconds.
  static const int connectionTimeoutSec = 15;

  /// Retry attempts before marking transfer as failed.
  static const int maxRetries = 3;

  /// Retry delay in milliseconds.
  static const int retryDelayMs = 2000;

  /// Application name.
  static const String appName = 'Fast Share';

  /// Database name.
  static const String dbName = 'fast_share.db';

  /// Database version.
  static const int dbVersion = 1;

  /// AES key length in bits.
  static const int aesKeyLength = 256;

  /// AES IV length in bytes.
  static const int aesIvLength = 16;

  /// Shake detection threshold (m/s²).
  static const double shakeThreshold = 15.0;

  /// Minimum interval between shake events (ms).
  static const int shakeMinIntervalMs = 500;
}
