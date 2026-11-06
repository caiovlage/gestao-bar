package br.com.bar.gestao.estoque.domain;

/**
 * Tipos de movimentação de estoque e o sentido de cada um.
 * Entradas sempre somam, saídas sempre subtraem e ajustes podem ir para os dois lados.
 */
public enum TipoMovimentacao {

    ENTRADA_MANUAL(Sentido.ENTRADA),
    ENTRADA_COMPRA(Sentido.ENTRADA),
    ESTORNO_VENDA(Sentido.ENTRADA),

    SAIDA_VENDA(Sentido.SAIDA),
    CONSUMO_RECEITA(Sentido.SAIDA),
    CONSUMO_INTERNO(Sentido.SAIDA),
    PERDA(Sentido.SAIDA),
    DEVOLUCAO_FORNECEDOR(Sentido.SAIDA),

    AJUSTE_INVENTARIO(Sentido.AJUSTE);

    public enum Sentido { ENTRADA, SAIDA, AJUSTE }

    private final Sentido sentido;

    TipoMovimentacao(Sentido sentido) {
        this.sentido = sentido;
    }

    public Sentido sentido() {
        return sentido;
    }

    /** Saídas que o operador pode registrar manualmente na tela de estoque. */
    public boolean isSaidaManual() {
        return this == CONSUMO_INTERNO || this == PERDA || this == DEVOLUCAO_FORNECEDOR;
    }
}
