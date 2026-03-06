import 'package:flutter/services.dart';

/// Method Channel bridge for Hotspot operations.
///
/// Communicates with native Kotlin/Swift code for:
/// - Creating a hotspot
/// - Getting hotspot credentials
/// - Stopping the hotspot
class HotspotChannel {
  static const _channel = MethodChannel('com.fastshare/hotspot');

  /// Creates a local hotspot for device-to-device connection.
  static Future<Map<String, String>?> createHotspot() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'createHotspot',
      );
      if (result != null) {
        return Map<String, String>.from(result);
      }
    } on PlatformException {
      // Fallback: hotspot creation not supported
    }
    return null;
  }

  /// Stops the active hotspot.
  static Future<void> stopHotspot() async {
    try {
      await _channel.invokeMethod<void>('stopHotspot');
    } on PlatformException {
      // Ignore
    }
  }

  /// Gets the current hotspot credentials (SSID, password).
  static Future<Map<String, String>?> getHotspotCredentials() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getHotspotCredentials',
      );
      if (result != null) {
        return Map<String, String>.from(result);
      }
    } on PlatformException {
      // Return null
    }
    return null;
  }

  /// Connects to a hotspot with the given SSID and password.
  static Future<bool> connectToHotspot({
    required String ssid,
    required String password,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('connectToHotspot', {
        'ssid': ssid,
        'password': password,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
