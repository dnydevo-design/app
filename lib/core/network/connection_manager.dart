import 'dart:async';
import 'dart:io';

import '../constants/app_constants.dart';

/// Manages active network connections with heartbeat monitoring
/// and automatic reconnection fallback.
///
/// Tracks all peer connections, detects drops via heartbeat,
/// and provides reconnection mechanisms.
class ConnectionManager {
  final Map<String, PeerInfo> _connections = {};
  final _eventController = StreamController<ConnectionEvent>.broadcast();
  Timer? _heartbeatTimer;

  /// Stream of connection lifecycle events.
  Stream<ConnectionEvent> get events => _eventController.stream;

  /// All currently active connections.
  Map<String, PeerInfo> get connections => Map.unmodifiable(_connections);

  /// Starts the heartbeat monitor.
  ///
  /// Pings all connections every [intervalSec] seconds.
  /// Connections that fail [maxMissedHeartbeats] consecutive times
  /// are marked as disconnected.
  void startHeartbeat({
    int intervalSec = 5,
    int maxMissedHeartbeats = 3,
  }) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: intervalSec),
      (_) => _checkHeartbeats(maxMissedHeartbeats),
    );
  }

  /// Stops the heartbeat monitor.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Registers a new peer connection.
  void addConnection({
    required String peerId,
    required String host,
    required int port,
    String? deviceName,
  }) {
    _connections[peerId] = PeerInfo(
      peerId: peerId,
      host: host,
      port: port,
      deviceName: deviceName ?? 'Unknown Device',
      status: ConnectionStatus.connected,
      lastSeen: DateTime.now(),
      missedHeartbeats: 0,
    );

    _eventController.add(ConnectionEvent(
      type: ConnectionEventType.connected,
      peerId: peerId,
      peerInfo: _connections[peerId]!,
    ));
  }

  /// Removes a peer connection.
  void removeConnection(String peerId) {
    final peer = _connections.remove(peerId);
    if (peer != null) {
      _eventController.add(ConnectionEvent(
        type: ConnectionEventType.disconnected,
        peerId: peerId,
        peerInfo: peer,
      ));
    }
  }

  /// Updates the last-seen timestamp for a peer (heartbeat received).
  void updateHeartbeat(String peerId) {
    final peer = _connections[peerId];
    if (peer != null) {
      _connections[peerId] = peer.copyWith(
        lastSeen: DateTime.now(),
        missedHeartbeats: 0,
        status: ConnectionStatus.connected,
      );
    }
  }

  /// Attempts to reconnect to a disconnected peer.
  ///
  /// Tries up to [maxRetries] times with [retryDelayMs] between attempts.
  Future<bool> reconnect(String peerId) async {
    final peer = _connections[peerId];
    if (peer == null) return false;

    _connections[peerId] = peer.copyWith(
      status: ConnectionStatus.reconnecting,
    );

    _eventController.add(ConnectionEvent(
      type: ConnectionEventType.reconnecting,
      peerId: peerId,
      peerInfo: _connections[peerId]!,
    ));

    for (var retry = 0; retry < AppConstants.maxRetries; retry++) {
      try {
        final socket = await Socket.connect(
          peer.host,
          peer.port,
          timeout: const Duration(seconds: AppConstants.connectionTimeoutSec),
        );
        await socket.close();

        _connections[peerId] = peer.copyWith(
          status: ConnectionStatus.connected,
          lastSeen: DateTime.now(),
          missedHeartbeats: 0,
        );

        _eventController.add(ConnectionEvent(
          type: ConnectionEventType.reconnected,
          peerId: peerId,
          peerInfo: _connections[peerId]!,
        ));

        return true;
      } on SocketException {
        await Future<void>.delayed(
          const Duration(milliseconds: AppConstants.retryDelayMs),
        );
      }
    }

    _connections[peerId] = peer.copyWith(
      status: ConnectionStatus.failed,
    );

    _eventController.add(ConnectionEvent(
      type: ConnectionEventType.failed,
      peerId: peerId,
      peerInfo: _connections[peerId]!,
    ));

    return false;
  }

  /// Checks heartbeats and marks unresponsive peers.
  Future<void> _checkHeartbeats(int maxMissed) async {
    for (final entry in _connections.entries) {
      final peer = entry.value;
      if (peer.status == ConnectionStatus.failed) continue;

      try {
        final socket = await Socket.connect(
          peer.host,
          peer.port,
          timeout: const Duration(seconds: 3),
        );
        await socket.close();

        _connections[entry.key] = peer.copyWith(
          lastSeen: DateTime.now(),
          missedHeartbeats: 0,
          status: ConnectionStatus.connected,
        );
      } on SocketException {
        final newMissed = peer.missedHeartbeats + 1;
        if (newMissed >= maxMissed) {
          _connections[entry.key] = peer.copyWith(
            missedHeartbeats: newMissed,
            status: ConnectionStatus.disconnected,
          );

          _eventController.add(ConnectionEvent(
            type: ConnectionEventType.disconnected,
            peerId: entry.key,
            peerInfo: _connections[entry.key]!,
          ));

          // Auto-attempt reconnection
          unawaited(reconnect(entry.key));
        } else {
          _connections[entry.key] = peer.copyWith(
            missedHeartbeats: newMissed,
          );
        }
      }
    }
  }

  /// Cleans up all resources.
  Future<void> dispose() async {
    stopHeartbeat();
    _connections.clear();
    await _eventController.close();
  }
}

/// Peer connection information.
class PeerInfo {
  final String peerId;
  final String host;
  final int port;
  final String deviceName;
  final ConnectionStatus status;
  final DateTime lastSeen;
  final int missedHeartbeats;

  const PeerInfo({
    required this.peerId,
    required this.host,
    required this.port,
    required this.deviceName,
    required this.status,
    required this.lastSeen,
    required this.missedHeartbeats,
  });

  PeerInfo copyWith({
    String? peerId,
    String? host,
    int? port,
    String? deviceName,
    ConnectionStatus? status,
    DateTime? lastSeen,
    int? missedHeartbeats,
  }) {
    return PeerInfo(
      peerId: peerId ?? this.peerId,
      host: host ?? this.host,
      port: port ?? this.port,
      deviceName: deviceName ?? this.deviceName,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      missedHeartbeats: missedHeartbeats ?? this.missedHeartbeats,
    );
  }
}

/// Connection lifecycle status.
enum ConnectionStatus {
  connected,
  disconnected,
  reconnecting,
  failed,
}

/// Connection lifecycle events.
enum ConnectionEventType {
  connected,
  disconnected,
  reconnecting,
  reconnected,
  failed,
}

/// Event emitted when a connection status changes.
class ConnectionEvent {
  final ConnectionEventType type;
  final String peerId;
  final PeerInfo peerInfo;

  const ConnectionEvent({
    required this.type,
    required this.peerId,
    required this.peerInfo,
  });
}
