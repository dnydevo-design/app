import 'package:equatable/equatable.dart';

/// Represents a file transfer task with full metadata.
class TransferTask extends Equatable {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final int totalChunks;
  final int completedChunks;
  final TransferDirection direction;
  final TransferStatus status;
  final String peerId;
  final String peerName;
  final double speedBytesPerSec;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const TransferTask({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.totalChunks,
    this.completedChunks = 0,
    required this.direction,
    this.status = TransferStatus.pending,
    required this.peerId,
    required this.peerName,
    this.speedBytesPerSec = 0,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  /// Progress as a fraction between 0.0 and 1.0.
  double get progress =>
      totalChunks > 0 ? completedChunks / totalChunks : 0.0;

  /// Whether the transfer can be resumed.
  bool get isResumable =>
      status == TransferStatus.paused ||
      status == TransferStatus.failed;

  TransferTask copyWith({
    String? id,
    String? fileName,
    String? filePath,
    int? fileSize,
    int? totalChunks,
    int? completedChunks,
    TransferDirection? direction,
    TransferStatus? status,
    String? peerId,
    String? peerName,
    double? speedBytesPerSec,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      totalChunks: totalChunks ?? this.totalChunks,
      completedChunks: completedChunks ?? this.completedChunks,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [id, status, completedChunks];
}

/// Direction of the transfer.
enum TransferDirection { send, receive }

/// Status of a transfer task.
enum TransferStatus {
  pending,
  connecting,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}
