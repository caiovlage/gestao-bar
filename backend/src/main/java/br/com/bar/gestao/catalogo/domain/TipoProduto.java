package br.com.bar.gestao.catalogo.domain;

/**
 * REVENDA: vendido ao cliente (cerveja lata, ou um lanche preparado por receita).
 * INGREDIENTE: usado apenas em receitas (batata congelada, óleo).
 * AMBOS: vendido e também usado como ingrediente.
 */
public enum TipoProduto {
    REVENDA,
    INGREDIENTE,
    AMBOS;

    public boolean isVendavel() {
        return this != INGREDIENTE;
    }
}
