import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../constants/app_constants.dart';
import '../utils/crc32_util.dart';

/// Manages 1-to-N file broadcasting to multiple receivers.
///
/// Reads file chunks and sends them concurrently to all connected peers.
/// Tracks acknowledgements to ensure delivery reliability.
class BroadcastManager {
  final Map<String, _PeerConnection> _peers = {};
  final _eventController = StreamController<BroadcastEvent>.broadcast();
  bool _isBroadcasting = false;

  /// Stream of broadcast events.
  Stream<BroadcastEvent> get events => _eventController.stream;

  /// Number of connected peers.
  int get peerCount => _peers.length;

  /// Whether a broadcast is in progress.
  bool get isBroadcasting => _isBroadcasting;

  /// Adds a peer to the broadcast group.
  void addPeer({
    required String peerId,
    required String host,
    int port = AppConstants.serverPort,
  }) {
    _peers[peerId] = _PeerConnection(
      peerId: peerId,
      host: host,
      port: port,
    );
    _eventController.add(BroadcastEvent(
      type: BroadcastEventType.peerAdded,
      peerId: peerId,
    ));
  }

  /// Removes a peer from the broadcast group.
  void removePeer(String peerId) {
    _peers.remove(peerId);
    _eventController.add(BroadcastEvent(
      type: BroadcastEventType.peerRemoved,
      peerId: peerId,
    ));
  }

  /// Broadcasts [filePath] to all connected peers.
  ///
  /// Reads the file in chunks, computes CRC32 for each, and sends them
  /// to every peer concurrently. Reports progress via [events] stream.
  Future<void> broadcastFile({
    required String transferId,
    required String filePath,
    int chunkSize = AppConstants.chunkSize,
  }) async {
    if (_peers.isEmpty || _isBroadcasting) return;

    _isBroadcasting = true;
    final file = File(filePath);
    final fileSize = await file.length();
    final totalChunks =
        (fileSize + chunkSize - 1) ~/ chunkSize;

    _eventController.add(BroadcastEvent(
      type: BroadcastEventType.started,
      data: {
        'transferId': transferId,
        'totalChunks': totalChunks,
        'fileSize': fileSize,
        'peerCount': _peers.length,
      },
    ));

    final raf = await file.open(mode: FileMode.read);

    try {
      for (var i = 0; i < totalChunks; i++) {
        final offset = i * chunkSize;
        final remaining = fileSize - offset;
        final currentChunkSize =
            remaining < chunkSize ? remaining.toInt() : chunkSize;

        await raf.setPosition(offset);
        final chunkBytes = await raf.read(currentChunkSize);
        final chunkData = Uint8List.fromList(chunkBytes);
        final checksum = Crc32Util.compute(chunkData);

        // Send to all peers concurrently
        final futures = _peers.values.map((peer) {
          return _sendChunkToPeer(
            peer: peer,
            transferId: transferId,
            chunkIndex: i,
            data: chunkData,
            checksum: checksum,
          );
        });

        final results = await Future.wait(
          futures,
          eagerError: false,
        );

        // Track per-peer results
        final failedPeers = <String>[];
        var peerIdx = 0;
        for (final peer in _peers.values) {
          if (!results.elementAt(peerIdx)) {
            failedPeers.add(peer.peerId);
          }
          peerIdx++;
        }

        _eventController.add(BroadcastEvent(
          type: BroadcastEventType.chunkSent,
          data: {
            'chunkIndex': i,
            'totalChunks': totalChunks,
            'failedPeers': failedPeers,
          },
        ));
      }

      _eventController.add(BroadcastEvent(
        type: BroadcastEventType.completed,
        data: {'transferId': transferId},
      ));
    } catch (e) {
      _eventController.add(BroadcastEvent(
        type: BroadcastEventType.error,
        data: {'error': e.toString()},
      ));
    } finally {
      await raf.close();
      _isBroadcasting = false;
    }
  }

  /// Sends a single chunk to a peer with retry logic.
  Future<bool> _sendChunkToPeer({
    required _PeerConnection peer,
    required String transferId,
    required int chunkIndex,
    required Uint8List data,
    required int checksum,
  }) async {
    final client = HttpClient();
    client.connectionTimeout =
        const Duration(seconds: AppConstants.connectionTimeoutSec);

    for (var retry = 0; retry < AppConstants.maxRetries; retry++) {
      try {
        final url = Uri.parse(
          'http://${peer.host}:${peer.port}'
          '/api/upload/$transferId/$chunkIndex',
        );

        final request = await client.postUrl(url);
        request.headers.set('Content-Type', 'application/octet-stream');
        request.headers.set('X-Checksum', checksum.toString());
        request.add(data);
        final response = await request.close();
        await response.drain<void>();

        if (response.statusCode == 200) {
          client.close();
          return true;
        }
      } on SocketException {
        // Connection dropped — mark for potential fallback
        _eventController.add(BroadcastEvent(
          type: BroadcastEventType.peerDisconnected,
          peerId: peer.peerId,
          data: {'chunkIndex': chunkIndex, 'retry': retry},
        ));
        await Future<void>.delayed(
          const Duration(milliseconds: AppConstants.retryDelayMs),
        );
      } catch (_) {
        await Future<void>.delayed(
          const Duration(milliseconds: AppConstants.retryDelayMs),
        );
      }
    }

    client.close();
    return false;
  }

  /// Cleans up all resources.
  Future<void> dispose() async {
    _peers.clear();
    _isBroadcasting = false;
    await _eventController.close();
  }
}

/// Peer connection metadata.
class _PeerConnection {
  final String peerId;
  final String host;
  final int port;

  const _PeerConnection({
    required this.peerId,
    required this.host,
    required this.port,
  });
}

/// Broadcast event types.
enum BroadcastEventType {
  peerAdded,
  peerRemoved,
  peerDisconnected,
  started,
  chunkSent,
  completed,
  error,
}

/// Event emitted during broadcast operations.
class BroadcastEvent {
  final BroadcastEventType type;
  final String? peerId;
  final Map<String, dynamic>? data;

  const BroadcastEvent({
    required this.type,
    this.peerId,
    this.data,
  });
}
