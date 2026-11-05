import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/categorias/categorias_page.dart';
import '../features/configuracoes/configuracoes_page.dart';
import '../features/em_breve/em_breve_page.dart';
import '../features/fornecedores/fornecedores_page.dart';
import '../features/produtos/produto_form_page.dart';
import '../features/produtos/produtos_page.dart';
import 'menu.dart';
import 'shell/admin_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Notifica o roteador sempre que o estado de autenticação muda.
  final atualizar = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => atualizar.value++);
  ref.onDispose(atualizar.dispose);

  return GoRouter(
    initialLocation: '/produtos',
    refreshListenable: atualizar,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final local = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) {
        return local == '/carregando' ? null : '/carregando';
      }
      final logado = auth.value != null;
      if (!logado) {
        return local == '/login' ? null : '/login';
      }
      if (local == '/login' || local == '/carregando') {
        return '/produtos';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/carregando', builder: (_, _) => const Scaffold(body: Carregando())),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/produtos', builder: (_, _) => const ProdutosPage()),
          GoRoute(path: '/produtos/novo', builder: (_, _) => const ProdutoFormPage()),
          GoRoute(
            path: '/produtos/:id',
            builder: (_, state) => ProdutoFormPage(produtoId: state.pathParameters['id']),
          ),
          GoRoute(path: '/categorias', builder: (_, _) => const CategoriasPage()),
          GoRoute(path: '/fornecedores', builder: (_, _) => const FornecedoresPage()),
          GoRoute(path: '/configuracoes', builder: (_, _) => const ConfiguracoesPage()),
          // Módulos das próximas etapas
          for (final item in itensMenu.where((i) => !i.disponivel))
            GoRoute(path: item.caminho, builder: (_, _) => EmBrevePage(item: item)),
        ],
      ),
    ],
  );
});
