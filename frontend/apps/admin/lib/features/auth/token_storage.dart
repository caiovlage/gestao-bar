import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o token JWT de forma segura (Keystore no Android, armazenamento criptografado na Web).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _chaveToken = 'auth_token';
  static const _chaveExpiracao = 'auth_expira_em';
  static const _chaveLogin = 'auth_login';

  final FlutterSecureStorage _storage;

  Future<void> salvar({required String token, required DateTime expiraEm, required String login}) async {
    await _storage.write(key: _chaveToken, value: token);
    await _storage.write(key: _chaveExpiracao, value: expiraEm.toUtc().toIso8601String());
    await _storage.write(key: _chaveLogin, value: login);
  }

  /// Retorna o token apenas se ainda não expirou.
  Future<String?> lerTokenValido() async {
    final token = await _storage.read(key: _chaveToken);
    final expiracao = DateTime.tryParse(await _storage.read(key: _chaveExpiracao) ?? '');
    if (token == null || expiracao == null || expiracao.isBefore(DateTime.now().toUtc())) {
      return null;
    }
    return token;
  }

  Future<String?> lerLogin() => _storage.read(key: _chaveLogin);

  Future<void> limpar() async {
    await _storage.delete(key: _chaveToken);
    await _storage.delete(key: _chaveExpiracao);
    await _storage.delete(key: _chaveLogin);
  }
}
