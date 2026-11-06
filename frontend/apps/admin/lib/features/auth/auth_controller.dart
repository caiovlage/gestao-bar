import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Usuário autenticado no painel.
class Sessao {
  const Sessao(this.login);
  final String login;
}

/// Estado da autenticação: carregando (restaurando sessão salva), null (deslogado) ou [Sessao].
final authProvider = AsyncNotifierProvider<AuthController, Sessao?>(AuthController.new);

class AuthController extends AsyncNotifier<Sessao?> {
  @override
  Future<Sessao?> build() async {
    final storage = ref.read(tokenStorageProvider);
    if (await storage.lerTokenValido() == null) {
      return null;
    }
    // Confirma com o servidor que o token salvo continua válido.
    try {
      final dados = await ref.read(apiClientProvider).get('/api/auth/sessao') as Map<String, dynamic>;
      return Sessao(dados['login'] as String);
    } on ApiException catch (e) {
      if (e.naoAutenticado) {
        await storage.limpar();
        return null;
      }
      // Servidor fora do ar: mantém a sessão local; as telas mostrarão o erro de conexão.
      final login = await storage.lerLogin();
      return login == null ? null : Sessao(login);
    }
  }

  /// Lança [ApiException] em caso de credenciais inválidas.
  Future<void> entrar(String login, String senha) async {
    final dados = await ref
        .read(apiClientProvider)
        .post('/api/auth/login', corpo: {'login': login, 'senha': senha}) as Map<String, dynamic>;
    await ref.read(tokenStorageProvider).salvar(
          token: dados['token'] as String,
          expiraEm: _lerInstante(dados['expiraEm']),
          login: dados['login'] as String,
        );
    state = AsyncData(Sessao(dados['login'] as String));
  }

  Future<void> sair() async {
    await ref.read(tokenStorageProvider).limpar();
    state = const AsyncData(null);
  }

  /// Aceita data ISO-8601 ("2026-11-07T04:51:23Z") ou segundos desde 1970 (número).
  static DateTime _lerInstante(Object? valor) {
    if (valor is num) {
      return DateTime.fromMillisecondsSinceEpoch((valor * 1000).round(), isUtc: true);
    }
    return DateTime.tryParse('$valor') ?? DateTime.now().add(const Duration(hours: 12));
  }

  /// Chamado pelo cliente HTTP quando a API responde 401.
  void sessaoExpirada() {
    if (state.value != null) {
      sair();
    }
  }
}
