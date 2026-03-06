import 'package:equatable/equatable.dart';

import '../../../domain/entities/transfer_task.dart';

/// Transfer BLoC states.
sealed class TransferState extends Equatable {
  const TransferState();
  @override
  List<Object?> get props => [];
}

/// Initial / idle state.
final class TransferInitial extends TransferState {
  const TransferInitial();
}

/// Loading transfers from database.
final class TransferLoading extends TransferState {
  const TransferLoading();
}

/// Transfers loaded successfully.
final class TransferLoaded extends TransferState {
  final List<TransferTask> transfers;
  final List<TransferTask> activeTransfers;

  const TransferLoaded({
    required this.transfers,
    required this.activeTransfers,
  });

  @override
  List<Object?> get props => [transfers, activeTransfers];
}

/// A transfer is in progress with real-time updates.
final class TransferInProgress extends TransferState {
  final TransferTask task;
  final List<TransferTask> allTransfers;

  const TransferInProgress({
    required this.task,
    required this.allTransfers,
  });

  @override
  List<Object?> get props => [task, allTransfers];
}

/// Transfer operation failed.
final class TransferError extends TransferState {
  final String message;
  final List<TransferTask> transfers;

  const TransferError({
    required this.message,
    this.transfers = const [],
  });

  @override
  List<Object?> get props => [message];
}
