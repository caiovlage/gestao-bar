package br.com.bar.gestao.shared.exception;

/** Falha de login. Retorna HTTP 401. */
public class AutenticacaoException extends RuntimeException {

    public AutenticacaoException(String mensagem) {
        super(mensagem);
    }
}
