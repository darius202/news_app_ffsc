import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/network/dio_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/news/data/datasources/news_local_data_source.dart';
import 'features/news/data/datasources/news_remote_data_source.dart';
import 'features/news/data/repositories/news_repository_impl.dart';
import 'features/news/domain/repositories/news_repository.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Persistance locale
  await Hive.initFlutter();
  final newsBox = await Hive.openBox<String>(NewsLocalDataSourceImpl.boxName);
  final authBox = await Hive.openBox<String>(AuthLocalDataSourceImpl.boxName);

  // Core
  final sessionExpired = StreamController<void>.broadcast();
  sl
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(Connectivity()))
    ..registerLazySingleton<TokenStorage>(
      () => SecureTokenStorage(const FlutterSecureStorage()),
    )
    ..registerLazySingleton<Dio>(
      () => createDioClient(
        tokenStorage: sl(),
        onSessionExpired: () => sessionExpired.add(null),
      ),
    )
    // Data sources
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(authBox),
    )
    ..registerLazySingleton<NewsRemoteDataSource>(
      () => NewsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<NewsLocalDataSource>(
      () => NewsLocalDataSourceImpl(newsBox),
    )
    // Repositories
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remote: sl(),
        local: sl(),
        tokenStorage: sl(),
        networkInfo: sl(),
        sessionExpiredStream: sessionExpired.stream,
      ),
    )
    ..registerLazySingleton<NewsRepository>(
      () => NewsRepositoryImpl(remote: sl(), local: sl(), networkInfo: sl()),
    );
}
