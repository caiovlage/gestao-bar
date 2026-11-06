package br.com.bar.gestao.venda.domain;

/** Forma de pagamento informada pelo operador (não há integração com maquininhas ou bancos). */
public enum FormaPagamento {
    DINHEIRO,
    PIX,
    CARTAO_DEBITO,
    CARTAO_CREDITO,
    OUTROS
}
