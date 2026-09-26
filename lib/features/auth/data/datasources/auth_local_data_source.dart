import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  UserModel getCachedUser();
  Future<void> clear();
}

/// Garde le profil utilisateur en cache (Hive) pour l'affichage hors-ligne.
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._box);

  static const boxName = 'auth_cache';
  static const _userKey = 'current_user';

  final Box<String> _box;

  @override
  Future<void> cacheUser(UserModel user) =>
      _box.put(_userKey, jsonEncode(user.toJson()));

  @override
  UserModel getCachedUser() {
    final raw = _box.get(_userKey);
    if (raw == null) throw const CacheException('Aucun profil en cache.');
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> clear() => _box.delete(_userKey);
}
