import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Events ─────────────────────────────────────────────

sealed class PermissionEvent extends Equatable {
  const PermissionEvent();
  @override
  List<Object?> get props => [];
}

final class CheckPermissionsEvent extends PermissionEvent {
  const CheckPermissionsEvent();
}

final class RequestPermissionsEvent extends PermissionEvent {
  const RequestPermissionsEvent();
}

// ─── States ─────────────────────────────────────────────

class PermissionState extends Equatable {
  final bool storageGranted;
  final bool locationGranted;
  final bool nearbyDevicesGranted;
  final bool cameraGranted;
  final bool allGranted;

  const PermissionState({
    this.storageGranted = false,
    this.locationGranted = false,
    this.nearbyDevicesGranted = false,
    this.cameraGranted = false,
    this.allGranted = false,
  });

  PermissionState copyWith({
    bool? storageGranted,
    bool? locationGranted,
    bool? nearbyDevicesGranted,
    bool? cameraGranted,
  }) {
    final storage = storageGranted ?? this.storageGranted;
    final location = locationGranted ?? this.locationGranted;
    final nearby = nearbyDevicesGranted ?? this.nearbyDevicesGranted;
    final camera = cameraGranted ?? this.cameraGranted;
    return PermissionState(
      storageGranted: storage,
      locationGranted: location,
      nearbyDevicesGranted: nearby,
      cameraGranted: camera,
      allGranted: storage && location && nearby,
    );
  }

  @override
  List<Object?> get props => [
        storageGranted,
        locationGranted,
        nearbyDevicesGranted,
        cameraGranted,
        allGranted,
      ];
}

// ─── BLoC ───────────────────────────────────────────────

/// Permission BLoC for Android 12+ granular permission management.
class PermissionBloc extends Bloc<PermissionEvent, PermissionState> {
  PermissionBloc() : super(const PermissionState()) {
    on<CheckPermissionsEvent>(_onCheck);
    on<RequestPermissionsEvent>(_onRequest);
  }

  Future<void> _onCheck(
    CheckPermissionsEvent event,
    Emitter<PermissionState> emit,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      emit(const PermissionState(
        storageGranted: true,
        locationGranted: true,
        nearbyDevicesGranted: true,
        cameraGranted: true,
        allGranted: true,
      ));
      return;
    }

    final storage = await _checkStoragePermission();
    final location = await Permission.locationWhenInUse.isGranted;
    final nearby = await _checkNearbyPermission();
    final camera = await Permission.camera.isGranted;

    emit(state.copyWith(
      storageGranted: storage,
      locationGranted: location,
      nearbyDevicesGranted: nearby,
      cameraGranted: camera,
    ));
  }

  Future<void> _onRequest(
    RequestPermissionsEvent event,
    Emitter<PermissionState> emit,
  ) async {
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.camera,
    ];

    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.nearbyWifiDevices,
      ]);
    }

    await permissions.request();
    add(const CheckPermissionsEvent());
  }

  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.isGranted;
      final manage = await Permission.manageExternalStorage.isGranted;
      return storage || manage;
    }
    return true;
  }

  Future<bool> _checkNearbyPermission() async {
    if (Platform.isAndroid) {
      return Permission.nearbyWifiDevices.isGranted;
    }
    return true;
  }
}
