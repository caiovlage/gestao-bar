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
  ItemMenu('Dashboard', Icons.dashboard_outlined, '/dashboard', etapa: 7,
      descricao: 'Faturamento, ticket médio, margens, produtos mais vendidos e alertas de estoque.'),
  ItemMenu('Vendas', Icons.point_of_sale_outlined, '/vendas', etapa: 4,
      descricao: 'Tela de vendas rápida (PDV), carrinho, formas de pagamento e cancelamentos.'),
  ItemMenu('Pedidos', Icons.receipt_long_outlined, '/pedidos', etapa: 6,
      descricao: 'Pedidos do cardápio digital, status de preparo e registro de pagamento.'),
  ItemMenu('Produtos', Icons.inventory_2_outlined, '/produtos'),
  ItemMenu('Categorias', Icons.category_outlined, '/categorias'),
  ItemMenu('Receitas', Icons.menu_book_outlined, '/receitas', etapa: 3,
      descricao: 'Fichas técnicas, ingredientes, adicionais e custo por porção.'),
  ItemMenu('Estoque', Icons.warehouse_outlined, '/estoque', etapa: 2,
      descricao: 'Movimentações, entradas, perdas, consumo interno e inventário.'),
  ItemMenu('Compras', Icons.shopping_cart_outlined, '/compras', etapa: 5,
      descricao: 'Sugestões de reposição, listas de compras e recebimento de mercadorias.'),
  ItemMenu('Fornecedores', Icons.local_shipping_outlined, '/fornecedores'),
  ItemMenu('Caixa', Icons.account_balance_wallet_outlined, '/caixa', etapa: 4,
      descricao: 'Abertura, sangrias, suprimentos e fechamento de caixa.'),
  ItemMenu('Despesas', Icons.request_quote_outlined, '/despesas', etapa: 7,
      descricao: 'Registro de despesas operacionais (água, luz, aluguel...).'),
  ItemMenu('Relatórios', Icons.insights_outlined, '/relatorios', etapa: 7,
      descricao: 'Relatórios gerenciais: vendas por período, margens, horários e giro de estoque.'),
  ItemMenu('Configurações', Icons.settings_outlined, '/configuracoes'),
];
