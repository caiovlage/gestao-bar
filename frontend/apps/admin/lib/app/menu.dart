import 'package:flutter/material.dart';

/// Item do menu lateral. [etapa] indica módulos ainda não implementados (mostram "Em breve").
class ItemMenu {
  const ItemMenu(this.rotulo, this.icone, this.caminho, {this.etapa, this.descricao});

  final String rotulo;
  final IconData icone;
  final String caminho;
  final int? etapa;
  final String? descricao;

  bool get disponivel => etapa == null;
}

const itensMenu = <ItemMenu>[
  ItemMenu('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  ItemMenu('Vendas', Icons.point_of_sale_outlined, '/vendas'),
  ItemMenu('Pedidos', Icons.receipt_long_outlined, '/pedidos'),
  ItemMenu('Produtos', Icons.inventory_2_outlined, '/produtos'),
  ItemMenu('Categorias', Icons.category_outlined, '/categorias'),
  ItemMenu('Receitas', Icons.menu_book_outlined, '/receitas'),
  ItemMenu('Estoque', Icons.warehouse_outlined, '/estoque'),
  ItemMenu('Compras', Icons.shopping_cart_outlined, '/compras'),
  ItemMenu('Fornecedores', Icons.local_shipping_outlined, '/fornecedores'),
  ItemMenu('Caixa', Icons.account_balance_wallet_outlined, '/caixa'),
  ItemMenu('Despesas', Icons.request_quote_outlined, '/despesas'),
  ItemMenu('Relatórios', Icons.insights_outlined, '/relatorios'),
  ItemMenu('Configurações', Icons.settings_outlined, '/configuracoes'),
];
