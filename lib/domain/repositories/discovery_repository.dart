import '../entities/device_info.dart';

/// Abstract repository contract for device discovery.
abstract class DiscoveryRepository {
  /// Starts scanning for nearby devices.
  Future<void> startDiscovery();

  /// Stops scanning.
  Future<void> stopDiscovery();

  /// Stream of discovered devices.
  Stream<List<DeviceInfo>> watchDevices();

  /// Gets the list of currently discovered devices.
  Future<List<DeviceInfo>> getDiscoveredDevices();

  /// Sends a discovery ping to announce this device.
  Future<void> announcePresence();

  /// Creates a Wi-Fi Direct group (becomes Group Owner).
  Future<bool> createGroup();

  /// Connects to a Wi-Fi Direct peer.
  Future<bool> connectToPeer(String peerId);

  /// Disconnects from all peers.
  Future<void> disconnect();

  /// Gets this device's connection info (IP, port, name).
  Future<DeviceInfo> getLocalDeviceInfo();
}
