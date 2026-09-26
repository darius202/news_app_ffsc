import '../../../../core/utils/result.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Result<User>> login({required String email, required String password});

  Future<Result<User>> register({
    required String name,
    required String email,
    required String password,
  });

  /// Révoque le refresh token côté serveur (si possible) et vide la session
  /// locale. Réussit toujours localement, même hors-ligne.
  Future<Result<void>> logout();

  /// Profil depuis `/api/me`, ou depuis le cache si hors-ligne.
  Future<Result<User>> getCurrentUser();

  Future<bool> hasSession();

  /// Émis lorsque le refresh token est invalide (session expirée).
  Stream<void> get onSessionExpired;
}
