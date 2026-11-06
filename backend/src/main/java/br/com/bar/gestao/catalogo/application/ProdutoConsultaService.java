package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.domain.Categoria;
import br.com.bar.gestao.catalogo.domain.CategoriaRepository;
import br.com.bar.gestao.catalogo.domain.Produto;
import br.com.bar.gestao.catalogo.domain.ProdutoEmbalagem;
import br.com.bar.gestao.catalogo.domain.ProdutoRepository;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import br.com.bar.gestao.catalogo.domain.UnidadeMedidaRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Fachada de leitura do catálogo para outros módulos (estoque, receitas, vendas, compras).
 * Não depende de nenhum outro módulo, evitando ciclos de dependência.
 */
@Service
public class ProdutoConsultaService {

    private final ProdutoRepository produtoRepository;
    private final UnidadeMedidaRepository unidadeRepository;
    private final CategoriaRepository categoriaRepository;
    private final ConversaoUnidadeService conversao;

    public ProdutoConsultaService(ProdutoRepository produtoRepository, UnidadeMedidaRepository unidadeRepository,
                                  CategoriaRepository categoriaRepository, ConversaoUnidadeService conversao) {
        this.produtoRepository = produtoRepository;
        this.unidadeRepository = unidadeRepository;
        this.categoriaRepository = categoriaRepository;
        this.conversao = conversao;
    }

    /** Dados essenciais de um produto para outros módulos. */
    public record ProdutoResumo(UUID id, String nome, String unidadeSigla, BigDecimal custoMedio, boolean ativo,
                                UUID categoriaId, String categoriaNome) {

        static ProdutoResumo of(Produto p) {
            return new ProdutoResumo(p.getId(), p.getNome(), p.getUnidadeEstoque().getSigla(), p.getCustoMedio(),
                    p.isAtivo(), p.getCategoria() == null ? null : p.getCategoria().getId(),
                    p.getCategoria() == null ? null : p.getCategoria().getNome());
        }
    }

    /** Quantidade convertida para a unidade de estoque e o texto de como foi informada (para auditoria). */
    public record Conversao(BigDecimal quantidadeEstoque, String quantidadeInformada) {
    }

    @Transactional(readOnly = true)
    public ProdutoResumo resumo(UUID produtoId) {
        return ProdutoResumo.of(carregar(produtoId));
    }

    @Transactional(readOnly = true)
    public Map<UUID, ProdutoResumo> resumos(Collection<UUID> produtoIds) {
        if (produtoIds.isEmpty()) {
            return Map.of();
        }
        return produtoRepository.findByIdIn(produtoIds).stream()
                .map(ProdutoResumo::of)
                .collect(Collectors.toMap(ProdutoResumo::id, Function.identity()));
    }

    @Transactional(readOnly = true)
    public String nomeCategoria(UUID categoriaId) {
        return categoriaRepository.findById(categoriaId).map(Categoria::getNome).orElse(null);
    }


    @Transactional(readOnly = true)
    public List<UUID> idsAtivos(UUID categoriaId) {
        return categoriaId == null ? produtoRepository.findIdsAtivos()
                : produtoRepository.findIdsAtivosPorCategoria(categoriaId);
    }

    /**
     * Converte uma quantidade informada em outra unidade (kg, L) ou embalagem (caixa, pacote)
     * para a unidade de estoque do produto. Sem unidade e sem embalagem, a quantidade já está
     * na unidade de estoque.
     */
    @Transactional(readOnly = true)
    public Conversao paraUnidadeEstoque(UUID produtoId, BigDecimal quantidade, UUID unidadeId, UUID embalagemId) {
        Produto produto = carregar(produtoId);
        UnidadeMedida estoque = produto.getUnidadeEstoque();
        boolean unidadeDeEstoque = unidadeId == null || unidadeId.equals(estoque.getId());

        if (embalagemId == null && unidadeDeEstoque) {
            return new Conversao(quantidade.setScale(ConversaoUnidadeService.ESCALA_QUANTIDADE, RoundingMode.HALF_UP), null);
        }

        BigDecimal convertida;
        String informada;
        if (embalagemId != null) {
            ProdutoEmbalagem embalagem = produto.embalagem(embalagemId)
                    .orElseThrow(() -> new NegocioException("EMBALAGEM_INVALIDA",
                            "A embalagem informada não pertence ao produto " + produto.getNome() + "."));
            convertida = conversao.embalagemParaEstoque(quantidade, embalagem);
            informada = texto(quantidade) + " × " + embalagem.getDescricao();
        } else {
            UnidadeMedida unidade = unidadeRepository.findById(unidadeId)
                    .orElseThrow(() -> new NegocioException("UNIDADE_INVALIDA", "Unidade de medida não existe."));
            convertida = conversao.converter(quantidade, unidade, estoque);
            informada = texto(quantidade) + " " + unidade.getSigla();
        }
        if (convertida.signum() == 0) {
            throw new NegocioException("QUANTIDADE_INVALIDA",
                    "A quantidade informada resulta em zero " + estoque.getSigla() + ".");
        }
        return new Conversao(convertida, informada);
    }

    private Produto carregar(UUID id) {
        return produtoRepository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Produto", id));
    }

    private static String texto(BigDecimal valor) {
        return valor.stripTrailingZeros().toPlainString();
    }
}
