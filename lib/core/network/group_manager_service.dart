import 'dart:async';
import 'package:flutter/foundation.dart';

class GroupManagerService {
  String? _currentRoomName;
  String? _roomPassword;
  bool _isAdmin = false;
  
  // List of connected device IPs/IDs
  final Map<String, ConnectedMember> _connectedMembers = {};
  
  // Ban list (IPs or IDs that are not allowed to join)
  final Set<String> _bannedDevices = {};

  final _membersController = StreamController<List<ConnectedMember>>.broadcast();

  Stream<List<ConnectedMember>> get watchMembers => _membersController.stream;
  bool get isAdmin => _isAdmin;
  String? get currentRoomName => _currentRoomName;

  /// Creates a new Sharing Room with optional password
  void createRoom({required String roomName, String? password}) {
    _currentRoomName = roomName;
    _roomPassword = password;
    _isAdmin = true;
    _connectedMembers.clear();
    _bannedDevices.clear();
    _notifyListeners();
  }

  /// Handles an incoming join request from a device
  bool processJoinRequest({
    required String deviceId, 
    required String deviceIp, 
    required String deviceName,
    String? providedPassword
  }) {
    if (_bannedDevices.contains(deviceId) || _bannedDevices.contains(deviceIp)) {
      debugPrint('Device $deviceId / $deviceIp is banned from joining.');
      return false; // Rejected
    }

    if (_roomPassword != null && _roomPassword!.isNotEmpty && providedPassword != _roomPassword) {
      debugPrint('Invalid password attempted by $deviceName');
      return false; // Rejected
    }

    // Accept and add member
    _connectedMembers[deviceId] = ConnectedMember(
      id: deviceId,
      ip: deviceIp,
      name: deviceName,
      joinedAt: DateTime.now(),
    );
    
    _notifyListeners();
    return true; // Accepted
  }

  /// Kicks a device off the network
  void kickMember(String deviceId) {
    if (!_isAdmin) return;
    final member = _connectedMembers.remove(deviceId);
    if (member != null) {
      debugPrint('Kicked member: ${member.name}');
      // Intended logic: Disconnect socket/TCP connection here
      _notifyListeners();
    }
  }

  /// Bans a device from the network (cannot rejoin)
  void banMember(String deviceId) {
    if (!_isAdmin) return;
    final member = _connectedMembers.remove(deviceId);
    if (member != null) {
      _bannedDevices.add(member.id);
      _bannedDevices.add(member.ip); // Ban IP as well for extra security
      debugPrint('Banned member: ${member.name}');
      // Intended logic: Disconnect socket/TCP connection here
      _notifyListeners();
    }
  }

  void _notifyListeners() {
    _membersController.add(_connectedMembers.values.toList());
  }

  void leaveRoom() {
    _currentRoomName = null;
    _roomPassword = null;
    _isAdmin = false;
    _connectedMembers.clear();
    _notifyListeners();
  }

  void dispose() {
    _membersController.close();
  }
}

class ConnectedMember {
  final String id;
  final String ip;
  final String name;
  final DateTime joinedAt;

  ConnectedMember({
    required this.id,
    required this.ip,
    required this.name,
    required this.joinedAt,
  });
}
