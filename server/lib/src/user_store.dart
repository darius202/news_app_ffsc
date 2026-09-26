import 'dart:convert';
import 'dart:io';

/// Stockage persistant très simple (fichier JSON) des utilisateurs et des
/// refresh tokens actifs. Suffisant pour un projet pédagogique.
class UserStore {
  UserStore(this._file);

  final File _file;
  final Map<String, Map<String, dynamic>> _users = {};
  // jti -> { userId, exp (ms depuis epoch) }
  final Map<String, Map<String, dynamic>> _refreshTokens = {};

  Future<void> load() async {
    if (!await _file.exists()) return;
    final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    (data['users'] as Map<String, dynamic>? ?? {}).forEach(
      (k, v) => _users[k] = Map<String, dynamic>.from(v as Map),
    );
    (data['refreshTokens'] as Map<String, dynamic>? ?? {}).forEach(
      (k, v) => _refreshTokens[k] = Map<String, dynamic>.from(v as Map),
    );
  }

  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'users': _users,
        'refreshTokens': _refreshTokens,
      }),
    );
  }

  Map<String, dynamic>? findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final user in _users.values) {
      if (user['email'] == normalized) return user;
    }
    return null;
  }

  Map<String, dynamic>? findById(String id) => _users[id];

  Future<void> insertUser(Map<String, dynamic> user) async {
    _users[user['id'] as String] = user;
    await _save();
  }

  Future<void> saveRefreshToken(String jti, String userId, DateTime exp) async {
    _refreshTokens[jti] = {
      'userId': userId,
      'exp': exp.millisecondsSinceEpoch,
    };
    _purgeExpired();
    await _save();
  }

  bool isRefreshTokenActive(String jti) {
    final entry = _refreshTokens[jti];
    if (entry == null) return false;
    return DateTime.now().millisecondsSinceEpoch < (entry['exp'] as int);
  }

  Future<void> revokeRefreshToken(String jti) async {
    if (_refreshTokens.remove(jti) != null) await _save();
  }

  void _purgeExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _refreshTokens.removeWhere((_, v) => (v['exp'] as int) < now);
  }
}
