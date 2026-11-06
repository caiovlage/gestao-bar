import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o token JWT da sessão.
///
/// - Android: armazenamento seguro do sistema (Keystore), via flutter_secure_storage.
/// - Web: localStorage do navegador, via shared_preferences. O flutter_secure_storage
///   não funciona na Web em HTTP (exige WebCrypto, disponível só em HTTPS/localhost),
///   e na Web ele também guardaria a chave de criptografia no próprio localStorage.
class TokenStorage {
  TokenStorage() : _armazenamento = kIsWeb ? _Navegador() : _Seguro();

  static const _chaveToken = 'auth_token';
  static const _chaveExpiracao = 'auth_expira_em';
  static const _chaveLogin = 'auth_login';

  final _Armazenamento _armazenamento;

  Future<void> salvar({required String token, required DateTime expiraEm, required String login}) async {
    await _armazenamento.gravar(_chaveToken, token);
    await _armazenamento.gravar(_chaveExpiracao, expiraEm.toUtc().toIso8601String());
    await _armazenamento.gravar(_chaveLogin, login);
  }

  /// Retorna o token apenas se ainda não expirou.
  Future<String?> lerTokenValido() async {
    final token = await _armazenamento.ler(_chaveToken);
    final expiracao = DateTime.tryParse(await _armazenamento.ler(_chaveExpiracao) ?? '');
    if (token == null || expiracao == null || expiracao.isBefore(DateTime.now().toUtc())) {
      return null;
    }
    return token;
  }

  Future<String?> lerLogin() => _armazenamento.ler(_chaveLogin);

  Future<void> limpar() async {
    await _armazenamento.remover(_chaveToken);
    await _armazenamento.remover(_chaveExpiracao);
    await _armazenamento.remover(_chaveLogin);
  }
}

abstract class _Armazenamento {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> remover(String chave);
}

class _Seguro implements _Armazenamento {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> ler(String chave) => _storage.read(key: chave);

  @override
  Future<void> gravar(String chave, String valor) => _storage.write(key: chave, value: valor);

  @override
  Future<void> remover(String chave) => _storage.delete(key: chave);
}

class _Navegador implements _Armazenamento {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> ler(String chave) => _prefs.getString(chave);

  @override
  Future<void> gravar(String chave, String valor) => _prefs.setString(chave, valor);

  @override
  Future<void> remover(String chave) => _prefs.remove(chave);
}
