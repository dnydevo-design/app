import '../../domain/entities/device_info.dart';

/// Data model for device discovery database operations.
class DeviceInfoModel {
  final String id;
  final String name;
  final String host;
  final int port;
  final String? platform;
  final String? avatar;
  final bool isGroupOwner;
  final String discoveredAt;

  const DeviceInfoModel({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.platform,
    this.avatar,
    this.isGroupOwner = false,
    required this.discoveredAt,
  });

  factory DeviceInfoModel.fromMap(Map<String, dynamic> map) {
    return DeviceInfoModel(
      id: map['id'] as String,
      name: map['name'] as String,
      host: map['host'] as String,
      port: map['port'] as int,
      platform: map['platform'] as String?,
      avatar: map['avatar'] as String?,
      isGroupOwner: (map['is_group_owner'] as int) == 1,
      discoveredAt: map['discovered_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'platform': platform,
      'avatar': avatar,
      'is_group_owner': isGroupOwner ? 1 : 0,
      'discovered_at': discoveredAt,
    };
  }

  DeviceInfo toEntity() {
    return DeviceInfo(
      id: id,
      name: name,
      host: host,
      port: port,
      platform: platform,
      avatar: avatar,
      isGroupOwner: isGroupOwner,
      discoveredAt: DateTime.parse(discoveredAt),
    );
  }

  factory DeviceInfoModel.fromEntity(DeviceInfo entity) {
    return DeviceInfoModel(
      id: entity.id,
      name: entity.name,
      host: entity.host,
      port: entity.port,
      platform: entity.platform,
      avatar: entity.avatar,
      isGroupOwner: entity.isGroupOwner,
      discoveredAt: entity.discoveredAt.toIso8601String(),
    );
  }
}
