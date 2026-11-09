import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/caixa/caixa_page.dart';
import '../features/categorias/categorias_page.dart';
import '../features/compras/compra_page.dart';
import '../features/compras/compras_page.dart';
import '../features/configuracoes/configuracoes_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/despesas/despesas_page.dart';
import '../features/em_breve/em_breve_page.dart';
import '../features/estoque/estoque_page.dart';
import '../features/estoque/inventario_page.dart';
import '../features/fornecedores/fornecedores_page.dart';
import '../features/pedidos/pedidos_page.dart';
import '../features/produtos/produto_form_page.dart';
import '../features/produtos/produtos_page.dart';
import '../features/receitas/receita_form_page.dart';
import '../features/receitas/receita_page.dart';
import '../features/receitas/receitas_page.dart';
import '../features/relatorios/relatorios_page.dart';
import '../features/vendas/pdv_page.dart';
import '../features/vendas/vendas_page.dart';
import 'menu.dart';
import 'shell/admin_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Notifica o roteador sempre que o estado de autenticação muda.
  final atualizar = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => atualizar.value++);
  ref.onDispose(atualizar.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
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
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/carregando', builder: (_, _) => const Scaffold(body: Carregando())),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      // PDV em tela cheia, fora do menu lateral do painel
      GoRoute(path: '/pdv', builder: (_, _) => const PdvPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/relatorios', builder: (_, _) => const RelatoriosPage()),
          GoRoute(path: '/despesas', builder: (_, _) => const DespesasPage()),
          GoRoute(path: '/pedidos', builder: (_, _) => const PedidosPage()),
          GoRoute(path: '/produtos', builder: (_, _) => const ProdutosPage()),
          GoRoute(
            path: '/produtos/novo',
            builder: (_, state) => ProdutoFormPage(codigoInicial: state.uri.queryParameters['codigo']),
          ),
          GoRoute(
            path: '/produtos/:id',
            builder: (_, state) => ProdutoFormPage(produtoId: state.pathParameters['id']),
          ),
          GoRoute(path: '/categorias', builder: (_, _) => const CategoriasPage()),
          GoRoute(
            path: '/vendas',
            builder: (_, state) => VendasPage(
              key: ValueKey(state.uri.queryParameters['caixaId']),
              caixaId: state.uri.queryParameters['caixaId'],
            ),
          ),
          GoRoute(path: '/caixa', builder: (_, _) => const CaixaPage()),
          GoRoute(path: '/compras', builder: (_, _) => const ComprasPage()),
          GoRoute(path: '/compras/nova', builder: (_, _) => const CompraPage()),
          GoRoute(path: '/compras/:id', builder: (_, state) => CompraPage(compraId: state.pathParameters['id'])),
          GoRoute(path: '/estoque', builder: (_, _) => const EstoquePage()),
          GoRoute(path: '/receitas', builder: (_, _) => const ReceitasPage()),
          GoRoute(path: '/receitas/nova', builder: (_, _) => const ReceitaFormPage()),
          GoRoute(
            path: '/receitas/:id/editar',
            builder: (_, state) => ReceitaFormPage(receitaId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/receitas/:id',
            builder: (_, state) => ReceitaPage(receitaId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/estoque/inventarios/:id',
            builder: (_, state) => InventarioPage(inventarioId: state.pathParameters['id']!),
          ),
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
