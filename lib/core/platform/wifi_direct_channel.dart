import 'package:flutter/services.dart';

/// Method Channel bridge for Wi-Fi Direct operations.
///
/// Communicates with native Kotlin/Swift code for:
/// - Device discovery
/// - Group creation
/// - Peer connection
/// - Hotspot management
class WifiDirectChannel {
  static const _channel = MethodChannel('com.fastshare/wifi_direct');

  /// Starts Wi-Fi Direct discovery.
  static Future<void> startDiscovery() async {
    try {
      await _channel.invokeMethod<void>('startDiscovery');
    } on PlatformException catch (e) {
      throw PlatformException(
        code: 'DISCOVERY_FAILED',
        message: 'Failed to start discovery: ${e.message}',
      );
    }
  }

  /// Stops Wi-Fi Direct discovery.
  static Future<void> stopDiscovery() async {
    try {
      await _channel.invokeMethod<void>('stopDiscovery');
    } on PlatformException {
      // Silently handle — not all platforms support this
    }
  }

  /// Creates a Wi-Fi Direct group, making this device the Group Owner.
  static Future<bool> createGroup() async {
    try {
      final result = await _channel.invokeMethod<bool>('createGroup');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Connects to a peer by [peerId].
  static Future<bool> connectToPeer(String peerId) async {
    try {
      final result = await _channel.invokeMethod<bool>('connectToPeer', {
        'peerId': peerId,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Gets the device's connection info.
  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceInfo',
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException {
      // Return null — caller handles fallback
    }
    return null;
  }

  /// Disconnects from all peers.
  static Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<void>('disconnect');
    } on PlatformException {
      // Ignore
    }
  }
}
