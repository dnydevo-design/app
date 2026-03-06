import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/repositories/discovery_repository.dart';

/// Implementation of [DiscoveryRepository] using Method Channels
/// for Wi-Fi Direct / Hotspot discovery on native platforms.
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  static const _channel = MethodChannel('com.fastshare/wifi_direct');
  final _uuid = const Uuid();

  final _devicesController = StreamController<List<DeviceInfo>>.broadcast();
  final List<DeviceInfo> _discoveredDevices = [];
  bool _isDiscovering = false;

  DiscoveryRepositoryImpl() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  /// Handles callbacks from native platform code.
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final device = DeviceInfo(
          id: data['id'] as String? ?? _uuid.v4(),
          name: data['name'] as String? ?? 'Unknown Device',
          host: data['host'] as String? ?? '0.0.0.0',
          port: data['port'] as int? ?? AppConstants.serverPort,
          platform: data['platform'] as String?,
          isGroupOwner: data['isGroupOwner'] as bool? ?? false,
          discoveredAt: DateTime.now(),
        );
        _addDevice(device);
      case 'onDeviceLost':
        final deviceId = call.arguments as String?;
        if (deviceId != null) {
          _removeDevice(deviceId);
        }
      case 'onConnectionChanged':
        // Handle connection state changes
        break;
    }
  }

  void _addDevice(DeviceInfo device) {
    _discoveredDevices.removeWhere((d) => d.id == device.id);
    _discoveredDevices.add(device);
    _devicesController.add(List.unmodifiable(_discoveredDevices));
  }

  void _removeDevice(String deviceId) {
    _discoveredDevices.removeWhere((d) => d.id == deviceId);
    _devicesController.add(List.unmodifiable(_discoveredDevices));
  }

  @override
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    try {
      await _channel.invokeMethod<void>('startDiscovery');
    } on PlatformException {
      // Fallback: Manual IP scanning on local network
      await _fallbackDiscovery();
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    try {
      await _channel.invokeMethod<void>('stopDiscovery');
    } on PlatformException {
      // Ignore — platform may not support this
    }
  }

  @override
  Stream<List<DeviceInfo>> watchDevices() => _devicesController.stream;

  @override
  Future<List<DeviceInfo>> getDiscoveredDevices() async {
    return List.unmodifiable(_discoveredDevices);
  }

  @override
  Future<void> announcePresence() async {
    try {
      await _channel.invokeMethod<void>('announcePresence', {
        'port': AppConstants.serverPort,
      });
    } on PlatformException {
      // Silently fail — discovery will work via fallback
    }
  }

  @override
  Future<bool> createGroup() async {
    try {
      final result = await _channel.invokeMethod<bool>('createGroup');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    try {
      final result = await _channel.invokeMethod<bool>('connectToPeer', {
        'peerId': peerId,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<void>('disconnect');
    } on PlatformException {
      // Ignore
    }
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  @override
  Future<DeviceInfo> getLocalDeviceInfo() async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceInfo');
      if (result != null) {
        final data = Map<String, dynamic>.from(result);
        return DeviceInfo(
          id: data['id'] as String? ?? _uuid.v4(),
          name: data['name'] as String? ?? 'This Device',
          host: data['host'] as String? ?? '0.0.0.0',
          port: AppConstants.serverPort,
          platform: data['platform'] as String?,
          discoveredAt: DateTime.now(),
        );
      }
    } on PlatformException {
      // Return default
    }

    return DeviceInfo(
      id: _uuid.v4(),
      name: 'Fast Share Device',
      host: '0.0.0.0',
      port: AppConstants.serverPort,
      platform: 'unknown',
      discoveredAt: DateTime.now(),
    );
  }

  /// Fallback discovery: scans common subnet IPs for running servers.
  Future<void> _fallbackDiscovery() async {
    // Simplified subnet scan — in production, determine the actual subnet
    // from network interfaces.
    // This is a placeholder for the actual network scan logic.
  }

  /// Disposes all resources.
  Future<void> dispose() async {
    await stopDiscovery();
    await _devicesController.close();
  }
}
