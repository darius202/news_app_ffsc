import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

import 'user_store.dart';

class AuthException implements Exception {
  AuthException(this.statusCode, this.message);
  final int statusCode;
  final String message;
}

class AuthService {
  AuthService({
    required this.store,
    required String secret,
    this.accessTtl = const Duration(minutes: 15),
    this.refreshTtl = const Duration(days: 7),
  }) : _key = SecretKey(secret);

  final UserStore store;
  final SecretKey _key;
  final Duration accessTtl;
  final Duration refreshTtl;
  final _uuid = const Uuid();
  final _random = Random.secure();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) throw AuthException(400, 'Le nom est requis.');
    if (!_emailRegex.hasMatch(email.trim())) {
      throw AuthException(400, 'Adresse e-mail invalide.');
    }
    if (password.length < 6) {
      throw AuthException(
        400,
        'Le mot de passe doit contenir au moins 6 caractères.',
      );
    }
    if (store.findByEmail(email) != null) {
      throw AuthException(409, 'Un compte existe déjà avec cet e-mail.');
    }
    final salt = _generateSalt();
    final user = <String, dynamic>{
      'id': _uuid.v4(),
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'salt': salt,
      'passwordHash': _hash(password, salt),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await store.insertUser(user);
    return _issueTokens(user);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final user = store.findByEmail(email);
    if (user == null ||
        _hash(password, user['salt'] as String) != user['passwordHash']) {
      throw AuthException(401, 'E-mail ou mot de passe incorrect.');
    }
    return _issueTokens(user);
  }

  /// Rotation : l'ancien refresh token est révoqué, un nouveau couple est émis.
  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final jwt = _verify(refreshToken, expectedType: 'refresh');
    final jti = jwt.jwtId;
    if (jti == null || !store.isRefreshTokenActive(jti)) {
      throw AuthException(401, 'Refresh token révoqué ou inconnu.');
    }
    final user = store.findById(jwt.subject ?? '');
    if (user == null) throw AuthException(401, 'Utilisateur introuvable.');
    await store.revokeRefreshToken(jti);
    return _issueTokens(user);
  }

  Future<void> logout(String refreshToken) async {
    try {
      final jwt = _verify(refreshToken, expectedType: 'refresh');
      if (jwt.jwtId != null) await store.revokeRefreshToken(jwt.jwtId!);
    } on AuthException {
      // Token déjà invalide : rien à révoquer.
    }
  }

  /// Vérifie un access token et renvoie l'utilisateur associé.
  Map<String, dynamic> authenticate(String accessToken) {
    final jwt = _verify(accessToken, expectedType: 'access');
    final user = store.findById(jwt.subject ?? '');
    if (user == null) throw AuthException(401, 'Utilisateur introuvable.');
    return user;
  }

  static Map<String, dynamic> publicUser(Map<String, dynamic> user) => {
    'id': user['id'],
    'name': user['name'],
    'email': user['email'],
    'createdAt': user['createdAt'],
  };

  Future<Map<String, dynamic>> _issueTokens(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final accessToken = JWT(
      {'type': 'access', 'email': user['email']},
      subject: userId,
      jwtId: _uuid.v4(),
    ).sign(_key, expiresIn: accessTtl);

    final refreshJti = _uuid.v4();
    final refreshToken = JWT(
      {'type': 'refresh'},
      subject: userId,
      jwtId: refreshJti,
    ).sign(_key, expiresIn: refreshTtl);
    await store.saveRefreshToken(
      refreshJti,
      userId,
      DateTime.now().add(refreshTtl),
    );

    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': accessTtl.inSeconds,
      'user': publicUser(user),
    };
  }

  JWT _verify(String token, {required String expectedType}) {
    try {
      final jwt = JWT.verify(token, _key);
      final payload = jwt.payload;
      if (payload is! Map || payload['type'] != expectedType) {
        throw AuthException(401, 'Type de token invalide.');
      }
      return jwt;
    } on JWTExpiredException {
      throw AuthException(401, 'Token expiré.');
    } on JWTException {
      throw AuthException(401, 'Token invalide.');
    }
  }

  String _generateSalt() =>
      base64Url.encode(List<int>.generate(16, (_) => _random.nextInt(256)));

  /// Hash itératif HMAC-SHA256 (façon PBKDF2 simplifiée).
  String _hash(String password, String salt) {
    List<int> bytes = utf8.encode(password);
    final hmac = Hmac(sha256, utf8.encode(salt));
    for (var i = 0; i < 10000; i++) {
      bytes = hmac.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }
}
