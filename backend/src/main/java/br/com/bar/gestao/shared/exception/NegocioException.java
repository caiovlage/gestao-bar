package br.com.bar.gestao.shared.exception;

/** Violação de regra de negócio. Retorna HTTP 422 com um código estável para o frontend. */
public class NegocioException extends RuntimeException {

    private final String codigo;

    public NegocioException(String codigo, String mensagem) {
        super(mensagem);
        this.codigo = codigo;
    }

    public String getCodigo() {
        return codigo;
    }
}
