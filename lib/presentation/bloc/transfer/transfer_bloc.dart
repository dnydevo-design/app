import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/transfer_task.dart';
import '../../../domain/repositories/transfer_repository.dart';
import 'transfer_event.dart';
import 'transfer_state.dart';

/// BLoC managing the transfer lifecycle.
///
/// Handles file transfer start, pause, resume, cancel, and progress tracking.
/// All heavy IO runs in isolates — the BLoC only orchestrates state transitions.
class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final TransferRepository _repository;
  StreamSubscription<TransferTask>? _progressSub;

  TransferBloc({required TransferRepository repository})
      : _repository = repository,
        super(const TransferInitial()) {
    on<LoadTransfersEvent>(_onLoadTransfers);
    on<StartTransferEvent>(_onStartTransfer);
    on<PauseTransferEvent>(_onPauseTransfer);
    on<ResumeTransferEvent>(_onResumeTransfer);
    on<CancelTransferEvent>(_onCancelTransfer);
    on<ClearHistoryEvent>(_onClearHistory);
  }

  Future<void> _onLoadTransfers(
    LoadTransfersEvent event,
    Emitter<TransferState> emit,
  ) async {
    emit(const TransferLoading());
    try {
      final transfers = await _repository.getAllTransfers();
      final active = await _repository.getActiveTransfers();
      emit(TransferLoaded(transfers: transfers, activeTransfers: active));
    } catch (e) {
      emit(TransferError(message: 'Failed to load transfers: $e'));
    }
  }

  Future<void> _onStartTransfer(
    StartTransferEvent event,
    Emitter<TransferState> emit,
  ) async {
    try {
      final task = await _repository.startTransfer(
        filePath: event.filePath,
        peerId: event.peerId,
        peerName: event.peerName,
        direction: event.isSending
            ? TransferDirection.send
            : TransferDirection.receive,
      );

      final allTransfers = await _repository.getAllTransfers();
      emit(TransferInProgress(task: task, allTransfers: allTransfers));

      // Watch for progress updates
      await _progressSub?.cancel();
      _progressSub = _repository.watchTransfer(task.id).listen((updated) {
        if (!isClosed) {
          add(const LoadTransfersEvent());
        }
      });
    } catch (e) {
      emit(TransferError(message: 'Failed to start transfer: $e'));
    }
  }

  Future<void> _onPauseTransfer(
    PauseTransferEvent event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await _repository.pauseTransfer(event.transferId);
      add(const LoadTransfersEvent());
    } catch (e) {
      emit(TransferError(message: 'Failed to pause transfer: $e'));
    }
  }

  Future<void> _onResumeTransfer(
    ResumeTransferEvent event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await _repository.resumeTransfer(event.transferId);
      add(const LoadTransfersEvent());
    } catch (e) {
      emit(TransferError(message: 'Failed to resume transfer: $e'));
    }
  }

  Future<void> _onCancelTransfer(
    CancelTransferEvent event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await _repository.cancelTransfer(event.transferId);
      add(const LoadTransfersEvent());
    } catch (e) {
      emit(TransferError(message: 'Failed to cancel transfer: $e'));
    }
  }

  Future<void> _onClearHistory(
    ClearHistoryEvent event,
    Emitter<TransferState> emit,
  ) async {
    try {
      await _repository.clearHistory();
      emit(const TransferLoaded(transfers: [], activeTransfers: []));
    } catch (e) {
      emit(TransferError(message: 'Failed to clear history: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _progressSub?.cancel();
    return super.close();
  }
}
