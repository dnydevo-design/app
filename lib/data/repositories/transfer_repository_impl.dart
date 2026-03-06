import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/broadcast_manager.dart';
import '../../core/network/connection_manager.dart';
import '../../core/network/isolate_client.dart';
import '../../core/network/isolate_server.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/transfer_task.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/local/transfer_local_datasource.dart';
import '../models/chunk_model.dart';
import '../models/transfer_task_model.dart';

/// Implementation of [TransferRepository] orchestrating the full transfer
/// lifecycle: server, client, broadcasting, chunk tracking, and DB persistence.
class TransferRepositoryImpl implements TransferRepository {
  final TransferLocalDatasource _localDatasource;
  final IsolateServer _server;
  final IsolateClient _client;
  final BroadcastManager _broadcastManager;
  final ConnectionManager _connectionManager;
  final _uuid = const Uuid();

  final _transferStreamControllers = <String, StreamController<TransferTask>>{};

  TransferRepositoryImpl({
    required TransferLocalDatasource localDatasource,
    required IsolateServer server,
    required IsolateClient client,
    required BroadcastManager broadcastManager,
    required ConnectionManager connectionManager,
  })  : _localDatasource = localDatasource,
        _server = server,
        _client = client,
        _broadcastManager = broadcastManager,
        _connectionManager = connectionManager;

  @override
  Future<TransferTask> startTransfer({
    required String filePath,
    required String peerId,
    required String peerName,
    required TransferDirection direction,
  }) async {
    try {
      final fileSize = await FileUtils.getFileSize(filePath);
      final totalChunks = FileUtils.calculateChunkCount(
        fileSize,
        AppConstants.chunkSize,
      );

      final task = TransferTask(
        id: _uuid.v4(),
        fileName: FileUtils.getFileName(filePath),
        filePath: filePath,
        fileSize: fileSize,
        totalChunks: totalChunks,
        direction: direction,
        status: TransferStatus.connecting,
        peerId: peerId,
        peerName: peerName,
        createdAt: DateTime.now(),
      );

      // Persist to DB
      await _localDatasource.insertTransfer(
        TransferTaskModel.fromEntity(task),
      );

      // Persist chunk metadata for resume support
      final chunks = List.generate(totalChunks, (i) {
        final offset = i * AppConstants.chunkSize;
        final remaining = fileSize - offset;
        final chunkSize = remaining < AppConstants.chunkSize
            ? remaining
            : AppConstants.chunkSize;
        return ChunkModel(
          transferId: task.id,
          chunkIndex: i,
          chunkOffset: offset,
          chunkSize: chunkSize,
          crc32Checksum: 0,
        );
      });
      await _localDatasource.insertChunks(chunks);

      // Start transfer based on direction
      if (direction == TransferDirection.send) {
        await _startSending(task);
      } else {
        await _startReceiving(task);
      }

      return task;
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to start transfer: $e');
    }
  }

  Future<void> _startSending(TransferTask task) async {
    // Ensure server is running
    if (!_server.isRunning) {
      await _server.start();
    }

    // For group sending, use broadcast manager
    final peer = _connectionManager.connections[task.peerId];
    if (peer != null) {
      _broadcastManager.addPeer(
        peerId: task.peerId,
        host: peer.host,
        port: peer.port,
      );

      // Listen for broadcast events
      _broadcastManager.events.listen((event) async {
        if (event.type == BroadcastEventType.chunkSent) {
          final chunkIndex = event.data?['chunkIndex'] as int? ?? 0;
          final totalChunks = event.data?['totalChunks'] as int? ?? 1;

          await updateProgress(
            transferId: task.id,
            completedChunks: chunkIndex + 1,
            speedBytesPerSec: 0,
          );

          if (chunkIndex + 1 >= totalChunks) {
            await completeTransfer(task.id);
          }
        }
      });

      unawaited(
        _broadcastManager.broadcastFile(
          transferId: task.id,
          filePath: task.filePath,
        ),
      );
    }
  }

  Future<void> _startReceiving(TransferTask task) async {
    final peer = _connectionManager.connections[task.peerId];
    if (peer == null) {
      throw const ConnectionException(message: 'Peer not found');
    }

    // Listen for download progress
    _client.progress.listen((progress) async {
      if (progress.transferId != task.id) return;

      switch (progress.event) {
        case DownloadEvent.chunkComplete:
          await _localDatasource.updateChunkStatus(
            transferId: task.id,
            chunkIndex: progress.chunkIndex,
            status: 'completed',
          );
          await updateProgress(
            transferId: task.id,
            completedChunks: progress.chunkIndex + 1,
            speedBytesPerSec: progress.speedBytesPerSec,
          );
        case DownloadEvent.complete:
          await completeTransfer(task.id);
        case DownloadEvent.error:
          await failTransfer(task.id, progress.errorMessage ?? 'Unknown error');
        default:
          break;
      }
    });

    await _client.startDownload(
      transferId: task.id,
      serverHost: peer.host,
      serverPort: peer.port,
      totalChunks: task.totalChunks,
      totalBytes: task.fileSize,
    );
  }

  @override
  Future<void> pauseTransfer(String transferId) async {
    _client.pause();
    await _localDatasource.updateStatus(transferId, 'paused');
    _notifyStream(transferId);
  }

  @override
  Future<void> resumeTransfer(String transferId) async {
    final task = await _localDatasource.getTransferById(transferId);
    if (task == null) return;

    final startChunk = await _localDatasource
        .getLastCompletedChunkIndex(transferId);

    await _localDatasource.updateStatus(transferId, 'transferring');

    if (task.direction == 'receive') {
      final peer = _connectionManager.connections[task.peerId];
      if (peer != null) {
        await _client.startDownload(
          transferId: transferId,
          serverHost: peer.host,
          serverPort: peer.port,
          totalChunks: task.totalChunks,
          totalBytes: task.fileSize,
          startChunk: startChunk,
        );
      }
    }

    _notifyStream(transferId);
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    await _client.cancel();
    await _localDatasource.updateStatus(transferId, 'cancelled');
    _notifyStream(transferId);
  }

  @override
  Future<List<TransferTask>> getAllTransfers() async {
    final models = await _localDatasource.getAllTransfers();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<TransferTask>> getActiveTransfers() async {
    final models = await _localDatasource.getActiveTransfers();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<TransferTask?> getTransferById(String transferId) async {
    final model = await _localDatasource.getTransferById(transferId);
    return model?.toEntity();
  }

  @override
  Future<void> updateProgress({
    required String transferId,
    required int completedChunks,
    required double speedBytesPerSec,
  }) async {
    await _localDatasource.updateProgress(
      transferId: transferId,
      completedChunks: completedChunks,
      speedBytesPerSec: speedBytesPerSec,
    );
    _notifyStream(transferId);
  }

  @override
  Future<void> completeTransfer(String transferId) async {
    await _localDatasource.updateStatus(transferId, 'completed');
    _notifyStream(transferId);
  }

  @override
  Future<void> failTransfer(String transferId, String errorMessage) async {
    final model = await _localDatasource.getTransferById(transferId);
    if (model != null) {
      final updated = TransferTaskModel(
        id: model.id,
        fileName: model.fileName,
        filePath: model.filePath,
        fileSize: model.fileSize,
        totalChunks: model.totalChunks,
        completedChunks: model.completedChunks,
        direction: model.direction,
        status: 'failed',
        peerId: model.peerId,
        peerName: model.peerName,
        speedBytesPerSec: 0,
        createdAt: model.createdAt,
        errorMessage: errorMessage,
      );
      await _localDatasource.updateTransfer(updated);
    }
    _notifyStream(transferId);
  }

  @override
  Future<void> clearHistory() async {
    await _localDatasource.clearAll();
  }

  @override
  Stream<TransferTask> watchTransfer(String transferId) {
    _transferStreamControllers[transferId] ??=
        StreamController<TransferTask>.broadcast();
    return _transferStreamControllers[transferId]!.stream;
  }

  Future<void> _notifyStream(String transferId) async {
    final controller = _transferStreamControllers[transferId];
    if (controller != null && !controller.isClosed) {
      final task = await getTransferById(transferId);
      if (task != null) {
        controller.add(task);
      }
    }
  }
}
