package br.com.bar.gestao.estoque.domain;

/** O que originou a movimentação (com origem_id apontando para o registro, quando houver). */
public enum OrigemMovimentacao {
    MANUAL,
    AJUSTE_AVULSO,
    INVENTARIO,
    COMPRA,
    VENDA,
    PEDIDO
}
