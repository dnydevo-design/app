import 'package:get_it/get_it.dart';

import 'core/network/broadcast_manager.dart';
import 'core/network/connection_manager.dart';
import 'core/network/isolate_client.dart';
import 'core/network/isolate_server.dart';
import 'data/datasources/local/database_helper.dart';
import 'data/datasources/local/transfer_local_datasource.dart';
import 'data/datasources/local/vault_local_datasource.dart';
import 'data/repositories/chat_repository_impl.dart';
import 'data/repositories/discovery_repository_impl.dart';
import 'data/repositories/file_repository_impl.dart';
import 'data/repositories/transfer_repository_impl.dart';
import 'data/repositories/vault_repository_impl.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/repositories/discovery_repository.dart';
import 'domain/repositories/file_repository.dart';
import 'domain/repositories/transfer_repository.dart';
import 'domain/repositories/vault_repository.dart';
import 'presentation/bloc/discovery/discovery_bloc.dart';
import 'presentation/bloc/locale/locale_cubit.dart';
import 'presentation/bloc/permission/permission_bloc.dart';
import 'presentation/bloc/theme/theme_cubit.dart';
import 'presentation/bloc/transfer/transfer_bloc.dart';

/// Global GetIt service locator instance.
final sl = GetIt.instance;

/// Initializes all dependencies.
Future<void> initDependencies() async {
  // ─── Core / Network ─────────────────────────────────
  sl.registerLazySingleton<IsolateServer>(() => IsolateServer());
  sl.registerLazySingleton<IsolateClient>(() => IsolateClient());
  sl.registerLazySingleton<BroadcastManager>(() => BroadcastManager());
  sl.registerLazySingleton<ConnectionManager>(() => ConnectionManager());

  // ─── Database ───────────────────────────────────────
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper.instance);

  // ─── Data Sources ───────────────────────────────────
  sl.registerLazySingleton<TransferLocalDatasource>(
    () => TransferLocalDatasource(dbHelper: sl()),
  );
  sl.registerLazySingleton<VaultLocalDatasource>(
    () => VaultLocalDatasource(dbHelper: sl()),
  );

  // ─── Repositories ──────────────────────────────────
  sl.registerLazySingleton<TransferRepository>(
    () => TransferRepositoryImpl(
      localDatasource: sl(),
      server: sl(),
      client: sl(),
      broadcastManager: sl(),
      connectionManager: sl(),
    ),
  );
  sl.registerLazySingleton<DiscoveryRepository>(
    () => DiscoveryRepositoryImpl(),
  );
  sl.registerLazySingleton<FileRepository>(
    () => FileRepositoryImpl(),
  );
  sl.registerLazySingleton<VaultRepository>(
    () => VaultRepositoryImpl(localDatasource: sl()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(),
  );

  // ─── BLoCs ─────────────────────────────────────────
  sl.registerFactory<TransferBloc>(
    () => TransferBloc(repository: sl()),
  );
  sl.registerFactory<DiscoveryBloc>(
    () => DiscoveryBloc(repository: sl()),
  );
  sl.registerFactory<PermissionBloc>(
    () => PermissionBloc(),
  );

  // ─── Cubits ────────────────────────────────────────
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit());
  sl.registerLazySingleton<LocaleCubit>(() => LocaleCubit());
}
