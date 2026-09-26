import 'package:dio/dio.dart';

import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(
    String name,
    String email,
    String password,
  );
  Future<void> logout(String refreshToken);
  Future<UserModel> me();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {AuthInterceptor.skipAuth: true});

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': email, 'password': password},
          options: _public,
        );
        return AuthResponseModel.fromJson(res.data!);
      });

  @override
  Future<AuthResponseModel> register(
    String name,
    String email,
    String password,
  ) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
      options: _public,
    );
    return AuthResponseModel.fromJson(res.data!);
  });

  @override
  Future<void> logout(String refreshToken) => _guard(
    () => _dio.post<void>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
      options: _public,
    ),
  );

  @override
  Future<UserModel> me() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/me');
    return UserModel.fromJson(res.data!);
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
