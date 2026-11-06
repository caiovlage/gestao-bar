package br.com.bar.gestao.shared.exception;

/** Muitas requisições de uma mesma origem em pouco tempo. Retorna HTTP 429. */
public class LimiteExcedidoException extends RuntimeException {

    public LimiteExcedidoException(String mensagem) {
        super(mensagem);
    }
}
