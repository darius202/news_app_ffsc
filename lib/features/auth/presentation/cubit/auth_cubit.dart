import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState()) {
    _sessionSub = _repository.onSessionExpired.listen((_) {
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
        ),
      );
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _sessionSub;

  Future<void> checkSession() async {
    if (!await _repository.hasSession()) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    final result = await _repository.getCurrentUser();
    switch (result) {
      case Success(:final data, :final fromCache):
        emit(
          AuthState(
            status: AuthStatus.authenticated,
            user: data,
            profileFromCache: fromCache,
          ),
        );
      case ResultFailure(failure: UnauthorizedFailure()):
        await _repository.logout();
        emit(const AuthState(status: AuthStatus.unauthenticated));
      case ResultFailure():
        // Tokens présents mais profil indisponible (hors-ligne sans cache) :
        // on laisse l'utilisateur accéder aux données en cache.
        emit(const AuthState(status: AuthStatus.authenticated));
    }
  }

  Future<void> login(String email, String password) => _submit(
    () => _repository.login(email: email, password: password),
  );

  Future<void> register(String name, String email, String password) =>
      _submit(
        () => _repository.register(
          name: name,
          email: email,
          password: password,
        ),
      );

  Future<void> _submit(Future<Result<User>> Function() action) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final result = await action();
    switch (result) {
      case Success(:final data):
        emit(AuthState(status: AuthStatus.authenticated, user: data));
      case ResultFailure(:final failure):
        emit(state.copyWith(isSubmitting: false, errorMessage: failure.message));
    }
  }

  Future<void> refreshProfile() async {
    final result = await _repository.getCurrentUser();
    switch (result) {
      case Success(:final data, :final fromCache):
        emit(
          state.copyWith(
            user: data,
            profileFromCache: fromCache,
            clearError: true,
          ),
        );
      case ResultFailure(:final failure):
        emit(state.copyWith(errorMessage: failure.message));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void clearError() => emit(state.copyWith(clearError: true));

  @override
  Future<void> close() {
    _sessionSub.cancel();
    return super.close();
  }
}
