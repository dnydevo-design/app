import 'package:equatable/equatable.dart';

/// Represents a discovered network device.
class DeviceInfo extends Equatable {
  final String id;
  final String name;
  final String host;
  final int port;
  final String? platform;
  final String? avatar;
  final bool isGroupOwner;
  final DateTime discoveredAt;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.platform,
    this.avatar,
    this.isGroupOwner = false,
    required this.discoveredAt,
  });

  @override
  List<Object?> get props => [id, host, port];
}
