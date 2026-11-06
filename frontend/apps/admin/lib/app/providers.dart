import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/token_storage.dart';

const _apiUrlInformada = String.fromEnvironment('API_URL');

/// Endereço da API.
/// - Produção (Web): sem API_URL, usa a origem da própria página (ex.: http://SERVIDOR).
///   O painel e a API saem pelo mesmo nginx na porta 80; o backend nunca é acessado direto.
/// - Desenvolvimento: flutter run --dart-define=API_URL=http://localhost:8080
/// - APK Android: flutter build apk --dart-define=API_URL=http://SERVIDOR
final apiUrl = _apiUrlInformada.isNotEmpty
    ? _apiUrlInformada
    : (kIsWeb ? Uri.base.origin : 'http://localhost:8080');

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Cliente HTTP único do app: injeta o token e encerra a sessão ao receber 401.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(
    baseUrl: apiUrl,
    lerToken: storage.lerTokenValido,
    aoNaoAutenticado: () => ref.read(authProvider.notifier).sessaoExpirada(),
  );
});
