import 'package:equatable/equatable.dart';

/// Base use case interface following Clean Architecture.
///
/// [Type] is the return type, [Params] is the input parameter type.
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Use case that requires no parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
