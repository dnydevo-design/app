import '../entities/transfer_task.dart';

/// Abstract repository contract for file transfers.
abstract class TransferRepository {
  /// Starts a new file transfer to [peerId].
  Future<TransferTask> startTransfer({
    required String filePath,
    required String peerId,
    required String peerName,
    required TransferDirection direction,
  });

  /// Pauses an active transfer.
  Future<void> pauseTransfer(String transferId);

  /// Resumes a paused transfer from the last completed chunk.
  Future<void> resumeTransfer(String transferId);

  /// Cancels and removes a transfer.
  Future<void> cancelTransfer(String transferId);

  /// Gets all transfer tasks.
  Future<List<TransferTask>> getAllTransfers();

  /// Gets active (in-progress) transfers.
  Future<List<TransferTask>> getActiveTransfers();

  /// Gets a specific transfer by ID.
  Future<TransferTask?> getTransferById(String transferId);

  /// Updates transfer progress.
  Future<void> updateProgress({
    required String transferId,
    required int completedChunks,
    required double speedBytesPerSec,
  });

  /// Marks a transfer as complete.
  Future<void> completeTransfer(String transferId);

  /// Marks a transfer as failed.
  Future<void> failTransfer(String transferId, String errorMessage);

  /// Deletes transfer history.
  Future<void> clearHistory();

  /// Stream of transfer updates for real-time UI.
  Stream<TransferTask> watchTransfer(String transferId);
}
