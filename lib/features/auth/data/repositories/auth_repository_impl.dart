import 'dart:async';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required TokenStorage tokenStorage,
    required NetworkInfo networkInfo,
    Stream<void>? sessionExpiredStream,
  }) : _remote = remote,
       _local = local,
       _tokenStorage = tokenStorage,
       _networkInfo = networkInfo,
       _sessionExpired = sessionExpiredStream ?? const Stream.empty();

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final TokenStorage _tokenStorage;
  final NetworkInfo _networkInfo;
  final Stream<void> _sessionExpired;

  @override
  Stream<void> get onSessionExpired => _sessionExpired;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) => _authenticate(() => _remote.login(email.trim(), password));

  @override
  Future<Result<User>> register({
    required String name,
    required String email,
    required String password,
  }) => _authenticate(
    () => _remote.register(name.trim(), email.trim(), password),
  );

  Future<Result<User>> _authenticate(
    Future<AuthResponseModel> Function() call,
  ) async {
    if (!await _networkInfo.isConnected) {
      return const ResultFailure(NetworkFailure());
    }
    try {
      final response = await call();
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      await _local.cacheUser(response.user);
      return Success(response.user);
    } on UnauthorizedException catch (e) {
      // Sur /auth/login, un 401 signifie "identifiants invalides".
      return ResultFailure(ServerFailure(e.message, statusCode: 401));
    } on AppException catch (e) {
      return ResultFailure(Failure.fromException(e));
    } catch (_) {
      return const ResultFailure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> logout() async {
    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken != null && await _networkInfo.isConnected) {
      try {
        await _remote.logout(refreshToken);
      } on AppException {
        // La révocation serveur est "best effort" : on déconnecte quand même.
      }
    }
    await _tokenStorage.clear();
    await _local.clear();
    return const Success(null);
  }

  @override
  Future<Result<User>> getCurrentUser() async {
    if (await _networkInfo.isConnected) {
      try {
        final user = await _remote.me();
        await _local.cacheUser(user);
        return Success(user);
      } on UnauthorizedException catch (e) {
        return ResultFailure(UnauthorizedFailure(e.message));
      } on AppException catch (e) {
        return _cachedUserOr(Failure.fromException(e));
      }
    }
    return _cachedUserOr(const NetworkFailure());
  }

  Result<User> _cachedUserOr(Failure failure) {
    try {
      return Success(_local.getCachedUser(), fromCache: true);
    } on CacheException {
      return ResultFailure(failure);
    }
  }

  @override
  Future<bool> hasSession() async => (await _tokenStorage.refreshToken) != null;
}
