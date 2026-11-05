import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/token_storage.dart';

/// URL da API. Defina na execução: flutter run --dart-define=API_URL=http://192.168.0.10:8080
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

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
