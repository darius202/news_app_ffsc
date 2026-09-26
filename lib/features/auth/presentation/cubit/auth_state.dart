part of 'auth_cubit.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.profileFromCache = false,
  });

  final AuthStatus status;
  final User? user;
  final bool isSubmitting;
  final String? errorMessage;
  final bool profileFromCache;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? profileFromCache,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    profileFromCache: profileFromCache ?? this.profileFromCache,
  );

  @override
  List<Object?> get props => [
    status,
    user,
    isSubmitting,
    errorMessage,
    profileFromCache,
  ];
}
