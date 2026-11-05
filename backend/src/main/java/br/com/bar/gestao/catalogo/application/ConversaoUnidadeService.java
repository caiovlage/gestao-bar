package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.domain.Produto;
import br.com.bar.gestao.catalogo.domain.ProdutoEmbalagem;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.util.UUID;

/**
 * Ponto único de conversão de quantidades. Todas as telas e módulos (estoque, receitas,
 * compras, vendas) devem converter por aqui para evitar inconsistências.
 * <ul>
 *   <li>Mesma grandeza (kg↔g, L↔ml): pelo fator_base da unidade.</li>
 *   <li>Embalagem (caixa, pacote): pelo fator da embalagem cadastrada no produto.</li>
 * </ul>
 * Quantidades de estoque são arredondadas a 3 casas (precisão da coluna).
 */
@Service
public class ConversaoUnidadeService {

    public static final int ESCALA_QUANTIDADE = 3;

    /** Converte entre unidades da mesma grandeza. Ex.: 2 kg → 2000 g. */
    public BigDecimal converter(BigDecimal quantidade, UnidadeMedida origem, UnidadeMedida destino) {
        exigirQuantidade(quantidade);
        if (origem.getId().equals(destino.getId())) {
            return escala(quantidade);
        }
        if (origem.isEmbalagem() || destino.isEmbalagem()) {
            throw new NegocioException("CONVERSAO_INVALIDA",
                    "Conversão de embalagem (" + origem.getSigla() + " → " + destino.getSigla()
                            + ") depende do produto. Use uma embalagem cadastrada no produto.");
        }
        if (origem.getGrandeza() != destino.getGrandeza()) {
            throw new NegocioException("UNIDADES_INCOMPATIVEIS",
                    "Não é possível converter " + origem.getSigla() + " em " + destino.getSigla() + ".");
        }
        BigDecimal emBase = quantidade.multiply(origem.getFatorBase());
        return escala(emBase.divide(destino.getFatorBase(), MathContext.DECIMAL64));
    }

    /** Converte uma quantidade de embalagens para a unidade de estoque. Ex.: 2 caixas de 12 → 24 un. */
    public BigDecimal embalagemParaEstoque(BigDecimal quantidade, ProdutoEmbalagem embalagem) {
        exigirQuantidade(quantidade);
        return escala(quantidade.multiply(embalagem.getFator()));
    }

    /**
     * Converte para a unidade de estoque do produto, a partir de uma unidade comum ou de uma embalagem.
     * Usado por compras (unidade de compra) e receitas (unidade da ficha técnica).
     */
    public BigDecimal paraUnidadeEstoque(Produto produto, BigDecimal quantidade, UnidadeMedida unidade, UUID embalagemId) {
        if (embalagemId != null) {
            ProdutoEmbalagem embalagem = produto.embalagem(embalagemId)
                    .orElseThrow(() -> new NegocioException("EMBALAGEM_INVALIDA",
                            "A embalagem informada não pertence ao produto " + produto.getNome() + "."));
            return embalagemParaEstoque(quantidade, embalagem);
        }
        return converter(quantidade, unidade, produto.getUnidadeEstoque());
    }

    private static void exigirQuantidade(BigDecimal quantidade) {
        if (quantidade == null) {
            throw new NegocioException("QUANTIDADE_INVALIDA", "Quantidade não informada.");
        }
    }

    private static BigDecimal escala(BigDecimal valor) {
        return valor.setScale(ESCALA_QUANTIDADE, RoundingMode.HALF_UP);
    }
}
