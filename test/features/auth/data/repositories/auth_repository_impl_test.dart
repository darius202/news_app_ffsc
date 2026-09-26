import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_app_ffsc/core/error/exceptions.dart';
import 'package:news_app_ffsc/core/error/failures.dart';
import 'package:news_app_ffsc/core/network/network_info.dart';
import 'package:news_app_ffsc/core/storage/token_storage.dart';
import 'package:news_app_ffsc/core/utils/result.dart';
import 'package:news_app_ffsc/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:news_app_ffsc/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:news_app_ffsc/features/auth/data/models/user_model.dart';
import 'package:news_app_ffsc/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:news_app_ffsc/features/auth/domain/entities/user.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

class MockLocal extends Mock implements AuthLocalDataSource {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockRemote remote;
  late MockLocal local;
  late MockTokenStorage tokens;
  late MockNetworkInfo networkInfo;
  late AuthRepositoryImpl repository;

  const user = UserModel(id: '42', name: 'Ada', email: 'ada@mail.com');
  const authResponse = AuthResponseModel(
    accessToken: 'access-123',
    refreshToken: 'refresh-456',
    user: user,
  );

  setUpAll(() => registerFallbackValue(user));

  setUp(() {
    remote = MockRemote();
    local = MockLocal();
    tokens = MockTokenStorage();
    networkInfo = MockNetworkInfo();
    repository = AuthRepositoryImpl(
      remote: remote,
      local: local,
      tokenStorage: tokens,
      networkInfo: networkInfo,
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(
      () => tokens.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
    when(() => tokens.clear()).thenAnswer((_) async {});
    when(() => local.cacheUser(any())).thenAnswer((_) async {});
    when(() => local.clear()).thenAnswer((_) async {});
  });

  group('login', () {
    test('succès : enregistre les tokens, met le profil en cache', () async {
      when(
        () => remote.login('ada@mail.com', 'secret'),
      ).thenAnswer((_) async => authResponse);

      final result = await repository.login(
        email: ' ada@mail.com ',
        password: 'secret',
      );

      expect((result as Success<User>).data, user);
      verify(
        () => tokens.saveTokens(
          accessToken: 'access-123',
          refreshToken: 'refresh-456',
        ),
      ).called(1);
      verify(() => local.cacheUser(user)).called(1);
    });

    test('identifiants invalides : renvoie le message du serveur', () async {
      when(() => remote.login(any(), any())).thenThrow(
        const UnauthorizedException('E-mail ou mot de passe incorrect.'),
      );

      final result = await repository.login(email: 'a@b.c', password: 'bad');

      final failure = (result as ResultFailure<User>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'E-mail ou mot de passe incorrect.');
      verifyNever(
        () => tokens.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('hors-ligne : renvoie une NetworkFailure sans appel API', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.login(email: 'a@b.c', password: 'x');

      expect((result as ResultFailure<User>).failure, isA<NetworkFailure>());
      verifyZeroInteractions(remote);
    });
  });

  group('register', () {
    test('e-mail déjà utilisé : renvoie une ServerFailure 409', () async {
      when(() => remote.register(any(), any(), any())).thenThrow(
        const ServerException('Un compte existe déjà.', statusCode: 409),
      );

      final result = await repository.register(
        name: 'Ada',
        email: 'ada@mail.com',
        password: 'secret1',
      );

      expect(
        (result as ResultFailure<User>).failure,
        const ServerFailure('Un compte existe déjà.', statusCode: 409),
      );
    });
  });

  group('logout', () {
    test('révoque le refresh token et vide la session locale', () async {
      when(() => tokens.refreshToken).thenAnswer((_) async => 'refresh-456');
      when(() => remote.logout('refresh-456')).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, isA<Success<void>>());
      verify(() => remote.logout('refresh-456')).called(1);
      verify(() => tokens.clear()).called(1);
      verify(() => local.clear()).called(1);
    });

    test('erreur serveur : déconnecte quand même localement', () async {
      when(() => tokens.refreshToken).thenAnswer((_) async => 'refresh-456');
      when(() => remote.logout(any())).thenThrow(const NetworkException());

      await repository.logout();

      verify(() => tokens.clear()).called(1);
    });
  });

  group('getCurrentUser', () {
    test('hors-ligne : renvoie le profil en cache', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => local.getCachedUser()).thenReturn(user);

      final result = await repository.getCurrentUser();

      final success = result as Success<User>;
      expect(success.data, user);
      expect(success.fromCache, isTrue);
      verifyNever(() => remote.me());
    });

    test('token révoqué : renvoie une UnauthorizedFailure', () async {
      when(() => remote.me()).thenThrow(const UnauthorizedException());

      final result = await repository.getCurrentUser();

      expect(
        (result as ResultFailure<User>).failure,
        isA<UnauthorizedFailure>(),
      );
    });
  });
}
