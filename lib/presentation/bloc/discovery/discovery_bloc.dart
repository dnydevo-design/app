import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/device_info.dart';
import '../../../domain/repositories/discovery_repository.dart';

// ─── Events ─────────────────────────────────────────────

sealed class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();
  @override
  List<Object?> get props => [];
}

final class StartDiscoveryEvent extends DiscoveryEvent {
  const StartDiscoveryEvent();
}

final class StopDiscoveryEvent extends DiscoveryEvent {
  const StopDiscoveryEvent();
}

final class ConnectToDeviceEvent extends DiscoveryEvent {
  final String peerId;
  const ConnectToDeviceEvent(this.peerId);
  @override
  List<Object?> get props => [peerId];
}

final class CreateGroupEvent extends DiscoveryEvent {
  const CreateGroupEvent();
}

final class DevicesUpdatedEvent extends DiscoveryEvent {
  final List<DeviceInfo> devices;
  const DevicesUpdatedEvent(this.devices);
  @override
  List<Object?> get props => [devices];
}

// ─── States ─────────────────────────────────────────────

sealed class DiscoveryState extends Equatable {
  const DiscoveryState();
  @override
  List<Object?> get props => [];
}

final class DiscoveryInitial extends DiscoveryState {
  const DiscoveryInitial();
}

final class DiscoveryScanning extends DiscoveryState {
  final List<DeviceInfo> devices;
  const DiscoveryScanning({this.devices = const []});
  @override
  List<Object?> get props => [devices];
}

final class DiscoveryFound extends DiscoveryState {
  final List<DeviceInfo> devices;
  const DiscoveryFound({required this.devices});
  @override
  List<Object?> get props => [devices];
}

final class DiscoveryConnecting extends DiscoveryState {
  final String peerId;
  const DiscoveryConnecting({required this.peerId});
  @override
  List<Object?> get props => [peerId];
}

final class DiscoveryConnected extends DiscoveryState {
  final DeviceInfo device;
  const DiscoveryConnected({required this.device});
  @override
  List<Object?> get props => [device];
}

final class DiscoveryError extends DiscoveryState {
  final String message;
  const DiscoveryError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final DiscoveryRepository _repository;
  StreamSubscription<List<DeviceInfo>>? _devicesSub;

  DiscoveryBloc({required DiscoveryRepository repository})
      : _repository = repository,
        super(const DiscoveryInitial()) {
    on<StartDiscoveryEvent>(_onStartDiscovery);
    on<StopDiscoveryEvent>(_onStopDiscovery);
    on<ConnectToDeviceEvent>(_onConnectToDevice);
    on<CreateGroupEvent>(_onCreateGroup);
    on<DevicesUpdatedEvent>(_onDevicesUpdated);
  }

  Future<void> _onStartDiscovery(
    StartDiscoveryEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    emit(const DiscoveryScanning());
    try {
      await _repository.announcePresence();
      await _repository.startDiscovery();

      await _devicesSub?.cancel();
      _devicesSub = _repository.watchDevices().listen((devices) {
        if (!isClosed) {
          add(DevicesUpdatedEvent(devices));
        }
      });
    } catch (e) {
      emit(DiscoveryError(message: 'Discovery failed: $e'));
    }
  }

  Future<void> _onStopDiscovery(
    StopDiscoveryEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    await _repository.stopDiscovery();
    await _devicesSub?.cancel();
    emit(const DiscoveryInitial());
  }

  void _onDevicesUpdated(
    DevicesUpdatedEvent event,
    Emitter<DiscoveryState> emit,
  ) {
    if (event.devices.isEmpty) {
      emit(const DiscoveryScanning());
    } else {
      emit(DiscoveryFound(devices: event.devices));
    }
  }

  Future<void> _onConnectToDevice(
    ConnectToDeviceEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    emit(DiscoveryConnecting(peerId: event.peerId));
    try {
      final success = await _repository.connectToPeer(event.peerId);
      if (success) {
        final devices = await _repository.getDiscoveredDevices();
        final device = devices.firstWhere((d) => d.id == event.peerId);
        emit(DiscoveryConnected(device: device));
      } else {
        emit(const DiscoveryError(message: 'Connection failed'));
      }
    } catch (e) {
      emit(DiscoveryError(message: 'Connection failed: $e'));
    }
  }

  Future<void> _onCreateGroup(
    CreateGroupEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    try {
      await _repository.createGroup();
    } catch (e) {
      emit(DiscoveryError(message: 'Failed to create group: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _devicesSub?.cancel();
    return super.close();
  }
}
