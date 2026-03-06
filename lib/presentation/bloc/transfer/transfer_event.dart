import 'package:equatable/equatable.dart';

/// Transfer BLoC events.
sealed class TransferEvent extends Equatable {
  const TransferEvent();
  @override
  List<Object?> get props => [];
}

/// Start a new file transfer.
final class StartTransferEvent extends TransferEvent {
  final String filePath;
  final String peerId;
  final String peerName;
  final bool isSending;

  const StartTransferEvent({
    required this.filePath,
    required this.peerId,
    required this.peerName,
    this.isSending = true,
  });

  @override
  List<Object?> get props => [filePath, peerId, isSending];
}

/// Pause an active transfer.
final class PauseTransferEvent extends TransferEvent {
  final String transferId;
  const PauseTransferEvent(this.transferId);
  @override
  List<Object?> get props => [transferId];
}

/// Resume a paused transfer.
final class ResumeTransferEvent extends TransferEvent {
  final String transferId;
  const ResumeTransferEvent(this.transferId);
  @override
  List<Object?> get props => [transferId];
}

/// Cancel a transfer.
final class CancelTransferEvent extends TransferEvent {
  final String transferId;
  const CancelTransferEvent(this.transferId);
  @override
  List<Object?> get props => [transferId];
}

/// Load all transfers from database.
final class LoadTransfersEvent extends TransferEvent {
  const LoadTransfersEvent();
}

/// Clear transfer history.
final class ClearHistoryEvent extends TransferEvent {
  const ClearHistoryEvent();
}
