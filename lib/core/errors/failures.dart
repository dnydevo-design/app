import 'package:equatable/equatable.dart';

/// Base failure class for the domain layer.
sealed class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server-side failures (shelf server errors).
final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Network/connection failures.
final class ConnectionFailure extends Failure {
  const ConnectionFailure({required super.message, super.code});
}

/// Database operation failures.
final class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.code});
}

/// File I/O failures.
final class FileFailure extends Failure {
  const FileFailure({required super.message, super.code});
}

/// Checksum validation failures.
final class ChecksumFailure extends Failure {
  const ChecksumFailure({required super.message, super.code});
}

/// Encryption/decryption failures.
final class CryptoFailure extends Failure {
  const CryptoFailure({required super.message, super.code});
}

/// Permission denied failures.
final class PermissionFailure extends Failure {
  const PermissionFailure({required super.message, super.code});
}

/// Transfer interrupted (pause, cancel, drop).
final class TransferInterrupted extends Failure {
  const TransferInterrupted({required super.message, super.code});
}

/// Timeout failure.
final class TimeoutFailure extends Failure {
  const TimeoutFailure({required super.message, super.code});
}
