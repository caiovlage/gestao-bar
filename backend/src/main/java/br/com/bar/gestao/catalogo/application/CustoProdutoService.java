package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.domain.Produto;
import br.com.bar.gestao.catalogo.domain.ProdutoRepository;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.util.UUID;

/**
 * Custo médio ponderado do produto, recalculado a cada recebimento de compra:
 * novo = (saldo anterior × custo anterior + quantidade comprada × custo da compra) ÷ (saldo anterior + quantidade).
 * Com saldo anterior zerado ou negativo, o custo passa a ser o da compra.
 */
@Service
public class CustoProdutoService {

    public static final int ESCALA_CUSTO = 6;

    private final ProdutoRepository repository;

    public CustoProdutoService(ProdutoRepository repository) {
        this.repository = repository;
    }

    public record Atualizacao(BigDecimal custoAnterior, BigDecimal custoNovo) {
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public Atualizacao registrarCompra(UUID produtoId, BigDecimal saldoAnterior, BigDecimal quantidade,
                                       BigDecimal custoUnitario) {
        Produto produto = repository.findById(produtoId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Produto", produtoId));
        BigDecimal anterior = produto.getCustoMedio();
        BigDecimal novo = custoMedioPonderado(saldoAnterior, anterior, quantidade, custoUnitario);
        produto.atualizarCustoMedio(novo);
        return new Atualizacao(anterior, novo);
    }

    public static BigDecimal custoMedioPonderado(BigDecimal saldoAnterior, BigDecimal custoAnterior,
                                                 BigDecimal quantidade, BigDecimal custoUnitario) {
        if (saldoAnterior.signum() <= 0) {
            return custoUnitario.setScale(ESCALA_CUSTO, RoundingMode.HALF_UP);
        }
        BigDecimal valorTotal = saldoAnterior.multiply(custoAnterior).add(quantidade.multiply(custoUnitario));
        return valorTotal.divide(saldoAnterior.add(quantidade), MathContext.DECIMAL64)
                .setScale(ESCALA_CUSTO, RoundingMode.HALF_UP);
    }
}
