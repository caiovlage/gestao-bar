package br.com.bar.gestao.estoque.application;

import br.com.bar.gestao.catalogo.application.ProdutoConsultaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService.ProdutoResumo;
import br.com.bar.gestao.estoque.api.dto.EstoqueDto;
import br.com.bar.gestao.estoque.domain.MovimentacaoEstoque;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Operações manuais da tela de estoque: entradas, saídas (perda, consumo interno, devolução) e ajustes. */
@Service
public class EstoqueOperacoesService {

    private final EstoqueService estoqueService;
    private final ProdutoConsultaService produtos;

    public EstoqueOperacoesService(EstoqueService estoqueService, ProdutoConsultaService produtos) {
        this.estoqueService = estoqueService;
        this.produtos = produtos;
    }

    @Transactional
    public EstoqueDto.MovimentacaoResponse registrarEntrada(EstoqueDto.EntradaRequest req) {
        ProdutoResumo produto = produtoControlado(req.produtoId());
        var conversao = produtos.paraUnidadeEstoque(req.produtoId(), req.quantidade(), req.unidadeId(), req.embalagemId());
        MovimentacaoEstoque mov = estoqueService.movimentar(new EstoqueService.Movimento(produto.id(), produto.nome(),
                produto.unidadeSigla(), TipoMovimentacao.ENTRADA_MANUAL, conversao.quantidadeEstoque(),
                produto.custoMedio(), conversao.quantidadeInformada(), OrigemMovimentacao.MANUAL, null,
                texto(req.observacao())));
        return resposta(mov, produto);
    }

    @Transactional
    public EstoqueDto.MovimentacaoResponse registrarSaida(EstoqueDto.SaidaRequest req) {
        if (!req.tipo().isSaidaManual()) {
            throw new NegocioException("TIPO_INVALIDO",
                    "Tipo de saída inválido. Use consumo interno, perda ou devolução ao fornecedor.");
        }
        if (req.tipo() == TipoMovimentacao.PERDA && texto(req.observacao()) == null) {
            throw new NegocioException("OBSERVACAO_OBRIGATORIA", "Informe o motivo da perda.");
        }
        ProdutoResumo produto = produtoControlado(req.produtoId());
        var conversao = produtos.paraUnidadeEstoque(req.produtoId(), req.quantidade(), req.unidadeId(), req.embalagemId());
        MovimentacaoEstoque mov = estoqueService.movimentar(new EstoqueService.Movimento(produto.id(), produto.nome(),
                produto.unidadeSigla(), req.tipo(), conversao.quantidadeEstoque().negate(), produto.custoMedio(),
                conversao.quantidadeInformada(), OrigemMovimentacao.MANUAL, null, texto(req.observacao())));
        return resposta(mov, produto);
    }

    /** Ajuste avulso de um produto: retorna a movimentação gerada, ou vazio se não houve diferença. */
    @Transactional
    public Optional<EstoqueDto.MovimentacaoResponse> ajustar(EstoqueDto.AjusteRequest req) {
        ProdutoResumo produto = produtoControlado(req.produtoId());
        List<EstoqueService.ResultadoAjuste> resultado = estoqueService.ajustarPara(List.of(new EstoqueService.AjusteAlvo(
                produto.id(), req.quantidadeContada(), produto.custoMedio(), OrigemMovimentacao.AJUSTE_AVULSO,
                null, texto(req.observacao()))));
        MovimentacaoEstoque mov = resultado.getFirst().movimentacao();
        return Optional.ofNullable(mov).map(m -> resposta(m, produto));
    }

    /** Produtos sem controle de estoque (pratos preparados) não aceitam movimentação. */
    private ProdutoResumo produtoControlado(UUID produtoId) {
        ProdutoResumo produto = produtos.resumo(produtoId);
        if (!produto.controlaEstoque()) {
            throw new NegocioException("PRODUTO_SEM_CONTROLE_ESTOQUE",
                    produto.nome() + " não tem controle de estoque (prato preparado).");
        }
        return produto;
    }

    static EstoqueDto.MovimentacaoResponse resposta(MovimentacaoEstoque m, ProdutoResumo p) {
        return new EstoqueDto.MovimentacaoResponse(m.getId(), m.getProdutoId(), p.nome(), p.unidadeSigla(), m.getTipo(),
                m.getQuantidade(), m.getSaldoAnterior(), m.getSaldoPosterior(), m.getCustoUnitario(),
                m.getQuantidadeInformada(), m.getOrigem(), m.getOrigemId(), m.getObservacao(), m.getDataHora());
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
