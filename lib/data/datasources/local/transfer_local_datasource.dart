import '../../../core/errors/exceptions.dart';
import '../../models/chunk_model.dart';
import '../../models/transfer_task_model.dart';
import 'database_helper.dart';

/// Local data source for transfer operations backed by sqflite.
class TransferLocalDatasource {
  final DatabaseHelper _dbHelper;

  TransferLocalDatasource({required DatabaseHelper dbHelper})
      : _dbHelper = dbHelper;

  /// Inserts a new transfer task.
  Future<void> insertTransfer(TransferTaskModel task) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('transfer_tasks', task.toMap());
    } catch (e) {
      throw DatabaseException(message: 'Failed to insert transfer: $e');
    }
  }

  /// Updates a transfer task.
  Future<void> updateTransfer(TransferTaskModel task) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'transfer_tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e) {
      throw DatabaseException(message: 'Failed to update transfer: $e');
    }
  }

  /// Gets a transfer by its ID.
  Future<TransferTaskModel?> getTransferById(String id) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'transfer_tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      return TransferTaskModel.fromMap(results.first);
    } catch (e) {
      throw DatabaseException(message: 'Failed to get transfer: $e');
    }
  }

  /// Gets all transfer tasks.
  Future<List<TransferTaskModel>> getAllTransfers() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'transfer_tasks',
        orderBy: 'created_at DESC',
      );
      return results.map(TransferTaskModel.fromMap).toList();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get transfers: $e');
    }
  }

  /// Gets active transfers (not completed/cancelled/failed).
  Future<List<TransferTaskModel>> getActiveTransfers() async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'transfer_tasks',
        where: 'status IN (?, ?, ?)',
        whereArgs: ['pending', 'connecting', 'transferring'],
        orderBy: 'created_at DESC',
      );
      return results.map(TransferTaskModel.fromMap).toList();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get active transfers: $e');
    }
  }

  /// Updates transfer progress.
  Future<void> updateProgress({
    required String transferId,
    required int completedChunks,
    required double speedBytesPerSec,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'transfer_tasks',
        {
          'completed_chunks': completedChunks,
          'speed_bytes_per_sec': speedBytesPerSec,
          'status': 'transferring',
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
    } catch (e) {
      throw DatabaseException(message: 'Failed to update progress: $e');
    }
  }

  /// Updates transfer status.
  Future<void> updateStatus(String transferId, String status) async {
    try {
      final db = await _dbHelper.database;
      final updates = <String, dynamic>{'status': status};
      if (status == 'completed') {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }
      await db.update(
        'transfer_tasks',
        updates,
        where: 'id = ?',
        whereArgs: [transferId],
      );
    } catch (e) {
      throw DatabaseException(message: 'Failed to update status: $e');
    }
  }

  /// Deletes a transfer and its chunks.
  Future<void> deleteTransfer(String transferId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'transfer_tasks',
        where: 'id = ?',
        whereArgs: [transferId],
      );
    } catch (e) {
      throw DatabaseException(message: 'Failed to delete transfer: $e');
    }
  }

  /// Clears all transfer history.
  Future<void> clearAll() async {
    try {
      final db = await _dbHelper.database;
      await db.delete('transfer_tasks');
      await db.delete('transfer_chunks');
    } catch (e) {
      throw DatabaseException(message: 'Failed to clear history: $e');
    }
  }

  // --- Chunk Operations ---

  /// Inserts chunk metadata for a transfer.
  Future<void> insertChunks(List<ChunkModel> chunks) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      for (final chunk in chunks) {
        batch.insert('transfer_chunks', chunk.toMap());
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException(message: 'Failed to insert chunks: $e');
    }
  }

  /// Updates a single chunk status.
  Future<void> updateChunkStatus({
    required String transferId,
    required int chunkIndex,
    required String status,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'transfer_chunks',
        {'status': status},
        where: 'transfer_id = ? AND chunk_index = ?',
        whereArgs: [transferId, chunkIndex],
      );
    } catch (e) {
      throw DatabaseException(message: 'Failed to update chunk status: $e');
    }
  }

  /// Gets the last completed chunk index for pause/resume.
  Future<int> getLastCompletedChunkIndex(String transferId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT MAX(chunk_index) as last_chunk FROM transfer_chunks '
        'WHERE transfer_id = ? AND status = ?',
        [transferId, 'completed'],
      );
      final lastChunk = result.first['last_chunk'];
      return lastChunk != null ? (lastChunk as int) + 1 : 0;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to get last completed chunk: $e',
      );
    }
  }

  /// Gets all pending chunks for a transfer (for resume).
  Future<List<ChunkModel>> getPendingChunks(String transferId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'transfer_chunks',
        where: 'transfer_id = ? AND status != ?',
        whereArgs: [transferId, 'completed'],
        orderBy: 'chunk_index ASC',
      );
      return results.map(ChunkModel.fromMap).toList();
    } catch (e) {
      throw DatabaseException(message: 'Failed to get pending chunks: $e');
    }
  }
}
