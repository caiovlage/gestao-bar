package br.com.bar.gestao.catalogo.domain;

/**
 * Grandeza física de uma unidade. Só há conversão automática dentro da mesma grandeza.
 * EMBALAGEM (caixa, pacote) não tem fator fixo: a conversão é definida por produto.
 */
public enum Grandeza {
    MASSA,
    VOLUME,
    UNIDADE,
    EMBALAGEM
}
