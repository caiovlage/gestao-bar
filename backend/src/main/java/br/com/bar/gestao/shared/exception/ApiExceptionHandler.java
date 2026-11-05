package br.com.bar.gestao.shared.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Tratamento padronizado de erros no formato RFC 7807 (application/problem+json).
 * Todo erro carrega a propriedade "codigo", usada pelo frontend para decidir a mensagem/ação.
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(NegocioException.class)
    public ProblemDetail negocio(NegocioException ex) {
        return problema(HttpStatus.UNPROCESSABLE_CONTENT, ex.getCodigo(), ex.getMessage());
    }

    @ExceptionHandler(RecursoNaoEncontradoException.class)
    public ProblemDetail naoEncontrado(RecursoNaoEncontradoException ex) {
        return problema(HttpStatus.NOT_FOUND, "NAO_ENCONTRADO", ex.getMessage());
    }

    @ExceptionHandler(AutenticacaoException.class)
    public ProblemDetail autenticacao(AutenticacaoException ex) {
        return problema(HttpStatus.UNAUTHORIZED, "NAO_AUTENTICADO", ex.getMessage());
    }

    @ExceptionHandler(OptimisticLockingFailureException.class)
    public ProblemDetail concorrencia(OptimisticLockingFailureException ex) {
        return problema(HttpStatus.CONFLICT, "CONFLITO_CONCORRENCIA",
                "O registro foi alterado por outra operação. Recarregue e tente novamente.");
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ProblemDetail integridade(DataIntegrityViolationException ex) {
        log.warn("Violação de integridade: {}", ex.getMostSpecificCause().getMessage());
        return problema(HttpStatus.CONFLICT, "VIOLACAO_INTEGRIDADE",
                "A operação conflita com dados existentes (registro duplicado ou em uso).");
    }

    @Override
    protected ResponseEntity<Object> handleMaxUploadSizeExceededException(MaxUploadSizeExceededException ex,
                                                                          HttpHeaders headers, HttpStatusCode status,
                                                                          WebRequest request) {
        return ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE).body(problema(HttpStatus.CONTENT_TOO_LARGE,
                "ARQUIVO_MUITO_GRANDE", "O arquivo excede o tamanho máximo permitido."));
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail inesperado(Exception ex) {
        log.error("Erro inesperado", ex);
        return problema(HttpStatus.INTERNAL_SERVER_ERROR, "ERRO_INTERNO", "Ocorreu um erro inesperado.");
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex, HttpHeaders headers,
                                                                  HttpStatusCode status, WebRequest request) {
        Map<String, String> campos = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(e -> campos.putIfAbsent(e.getField(), e.getDefaultMessage()));
        ProblemDetail pd = problema(HttpStatus.BAD_REQUEST, "DADOS_INVALIDOS", "Existem campos inválidos.");
        pd.setProperty("campos", campos);
        return ResponseEntity.badRequest().body(pd);
    }

    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(HttpMessageNotReadableException ex, HttpHeaders headers,
                                                                  HttpStatusCode status, WebRequest request) {
        log.debug("Corpo da requisição ilegível", ex);
        return ResponseEntity.badRequest().body(problema(HttpStatus.BAD_REQUEST, "CORPO_INVALIDO",
                "O corpo da requisição está malformado ou contém valores de tipo inválido."));
    }

    /** Erros tratados pelo próprio Spring (JSON malformado, método não suportado...) também recebem "codigo". */
    @Override
    protected ResponseEntity<Object> createResponseEntity(Object body, HttpHeaders headers, HttpStatusCode statusCode,
                                                          WebRequest request) {
        if (body instanceof ProblemDetail pd && (pd.getProperties() == null || !pd.getProperties().containsKey("codigo"))) {
            pd.setProperty("codigo", "REQUISICAO_INVALIDA");
            pd.setProperty("timestamp", Instant.now());
        }
        return super.createResponseEntity(body, headers, statusCode, request);
    }

    public static ProblemDetail problema(HttpStatus status, String codigo, String mensagem) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(status, mensagem);
        pd.setProperty("codigo", codigo);
        pd.setProperty("timestamp", Instant.now());
        return pd;
    }
}
