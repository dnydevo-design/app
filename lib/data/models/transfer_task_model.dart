import '../../domain/entities/transfer_task.dart';

/// Data model mapping between TransferTask entity and database rows.
class TransferTaskModel {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final int totalChunks;
  final int completedChunks;
  final String direction;
  final String status;
  final String peerId;
  final String peerName;
  final double speedBytesPerSec;
  final String createdAt;
  final String? completedAt;
  final String? errorMessage;

  const TransferTaskModel({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.totalChunks,
    this.completedChunks = 0,
    required this.direction,
    this.status = 'pending',
    required this.peerId,
    required this.peerName,
    this.speedBytesPerSec = 0,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  /// Creates from a database row.
  factory TransferTaskModel.fromMap(Map<String, dynamic> map) {
    return TransferTaskModel(
      id: map['id'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int,
      totalChunks: map['total_chunks'] as int,
      completedChunks: map['completed_chunks'] as int,
      direction: map['direction'] as String,
      status: map['status'] as String,
      peerId: map['peer_id'] as String,
      peerName: map['peer_name'] as String,
      speedBytesPerSec: (map['speed_bytes_per_sec'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      completedAt: map['completed_at'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }

  /// Converts to a database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'total_chunks': totalChunks,
      'completed_chunks': completedChunks,
      'direction': direction,
      'status': status,
      'peer_id': peerId,
      'peer_name': peerName,
      'speed_bytes_per_sec': speedBytesPerSec,
      'created_at': createdAt,
      'completed_at': completedAt,
      'error_message': errorMessage,
    };
  }

  /// Converts to a domain entity.
  TransferTask toEntity() {
    return TransferTask(
      id: id,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      totalChunks: totalChunks,
      completedChunks: completedChunks,
      direction: _parseDirection(direction),
      status: _parseStatus(status),
      peerId: peerId,
      peerName: peerName,
      speedBytesPerSec: speedBytesPerSec,
      createdAt: DateTime.parse(createdAt),
      completedAt: completedAt != null ? DateTime.parse(completedAt!) : null,
      errorMessage: errorMessage,
    );
  }

  /// Creates from a domain entity.
  factory TransferTaskModel.fromEntity(TransferTask entity) {
    return TransferTaskModel(
      id: entity.id,
      fileName: entity.fileName,
      filePath: entity.filePath,
      fileSize: entity.fileSize,
      totalChunks: entity.totalChunks,
      completedChunks: entity.completedChunks,
      direction: entity.direction.name,
      status: entity.status.name,
      peerId: entity.peerId,
      peerName: entity.peerName,
      speedBytesPerSec: entity.speedBytesPerSec,
      createdAt: entity.createdAt.toIso8601String(),
      completedAt: entity.completedAt?.toIso8601String(),
      errorMessage: entity.errorMessage,
    );
  }

  static TransferDirection _parseDirection(String value) {
    return TransferDirection.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransferDirection.send,
    );
  }

  static TransferStatus _parseStatus(String value) {
    return TransferStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransferStatus.pending,
    );
  }
}
