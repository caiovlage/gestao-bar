package br.com.bar.gestao.compra.application;

import br.com.bar.gestao.catalogo.application.CustoProdutoService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService.ProdutoResumo;
import br.com.bar.gestao.compra.api.dto.CompraDto;
import br.com.bar.gestao.compra.domain.Compra;
import br.com.bar.gestao.compra.domain.CompraItem;
import br.com.bar.gestao.compra.domain.CompraRepository;
import br.com.bar.gestao.compra.domain.HistoricoCusto;
import br.com.bar.gestao.compra.domain.HistoricoCustoRepository;
import br.com.bar.gestao.estoque.application.EstoqueService;
import br.com.bar.gestao.estoque.domain.MovimentacaoEstoque;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.fornecedor.application.FornecedorService;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Listas de compras e recebimento. No recebimento, numa única transação, cada item:
 * entra no estoque (ENTRADA_COMPRA), atualiza o custo médio ponderado do produto e
 * registra o preço de aquisição no histórico.
 */
@Service
public class CompraService {

    private static final Logger log = LoggerFactory.getLogger(CompraService.class);

    private final CompraRepository repository;
    private final HistoricoCustoRepository historicoRepository;
    private final ProdutoConsultaService produtos;
    private final CustoProdutoService custos;
    private final EstoqueService estoqueService;
    private final FornecedorService fornecedores;

    public CompraService(CompraRepository repository, HistoricoCustoRepository historicoRepository,
                         ProdutoConsultaService produtos, CustoProdutoService custos, EstoqueService estoqueService,
                         FornecedorService fornecedores) {
        this.repository = repository;
        this.historicoRepository = historicoRepository;
        this.produtos = produtos;
        this.custos = custos;
        this.estoqueService = estoqueService;
        this.fornecedores = fornecedores;
    }

    // ---------------------------------------------------------------- listas

    @Transactional
    public CompraDto.Response criar(CompraDto.Request req) {
        Compra compra = new Compra(repository.proximoNumero());
        aplicar(compra, req);
        repository.save(compra);
        log.info("Lista de compras nº {} criada com {} item(ns)", compra.getNumero(), compra.getItens().size());
        return resposta(compra);
    }

    /**
     * Cria uma lista a partir das sugestões: compra o que falta para chegar ao mínimo, arredondado
     * para cima em embalagens quando o produto tiver (ex.: faltam 36 latas → 3 caixas de 12),
     * pelo custo médio atual como preço estimado.
     */
    @Transactional
    public CompraDto.Response criarDaSugestao(CompraDto.DaSugestaoRequest req) {
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(req.produtoIds());
        Map<UUID, BigDecimal> saldos = estoqueService.quantidades(req.produtoIds());
        List<CompraDto.ItemRequest> itens = new ArrayList<>();
        for (UUID id : req.produtoIds()) {
            ProdutoResumo p = resumos.get(id);
            if (p == null || !p.controlaEstoque()) continue;
            BigDecimal falta = produtos.estoqueMinimo(id).subtract(saldos.getOrDefault(id, BigDecimal.ZERO));
            if (falta.signum() <= 0) continue;
            var embalagem = produtos.maiorEmbalagem(id);
            if (embalagem.isPresent()) {
                BigDecimal caixas = falta.divide(embalagem.get().fator(), 0, RoundingMode.CEILING);
                itens.add(new CompraDto.ItemRequest(id, caixas, null, embalagem.get().id(),
                        p.custoMedio().multiply(embalagem.get().fator()).setScale(4, RoundingMode.HALF_UP)));
            } else {
                itens.add(new CompraDto.ItemRequest(id, falta, null, null, p.custoMedio().setScale(4, RoundingMode.HALF_UP)));
            }
        }
        if (itens.isEmpty()) {
            throw new NegocioException("SEM_SUGESTOES", "Nenhum dos produtos selecionados está abaixo do mínimo.");
        }
        return criar(new CompraDto.Request(req.fornecedorId(), null, itens));
    }

    @Transactional
    public CompraDto.Response atualizar(UUID id, CompraDto.Request req) {
        Compra compra = carregar(id);
        aplicar(compra, req);
        return resposta(compra);
    }

    @Transactional
    public CompraDto.Response cancelar(UUID id) {
        Compra compra = carregar(id);
        compra.cancelar();
        log.info("Lista de compras nº {} cancelada", compra.getNumero());
        return resposta(compra);
    }

    // ---------------------------------------------------------------- recebimento

    @Transactional
    public CompraDto.Response receber(UUID id) {
        Compra compra = repository.travar(id).orElseThrow(() -> new RecursoNaoEncontradoException("Compra", id));
        compra.receber();
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(compra.getItens().stream().map(CompraItem::getProdutoId).toList());

        for (CompraItem item : compra.getItens()) {
            ProdutoResumo p = resumos.get(item.getProdutoId());
            if (p == null || !p.controlaEstoque()) {
                throw new NegocioException("PRODUTO_SEM_CONTROLE_ESTOQUE",
                        item.getProdutoNome() + " não tem controle de estoque e não pode ser recebido.");
            }
            BigDecimal custoEstoque = item.custoUnitarioEstoque();
            MovimentacaoEstoque mov = estoqueService.movimentar(new EstoqueService.Movimento(p.id(), p.nome(),
                    p.unidadeSigla(), TipoMovimentacao.ENTRADA_COMPRA, item.getQuantidadeEstoque(), custoEstoque,
                    texto(item.getQuantidade()) + " × " + item.getUnidadeCompra(), OrigemMovimentacao.COMPRA,
                    compra.getId(), "Compra nº " + compra.getNumero()));
            var custo = custos.registrarCompra(p.id(), mov.getSaldoAnterior(), item.getQuantidadeEstoque(), custoEstoque);
            historicoRepository.save(new HistoricoCusto(p.id(), compra.getFornecedorId(), compra.getId(),
                    item.getQuantidadeEstoque(), custoEstoque, custo.custoAnterior(), custo.custoNovo()));
        }
        log.info("Compra nº {} recebida: {} item(ns), total {}", compra.getNumero(), compra.getItens().size(), compra.getTotal());
        return resposta(compra);
    }

    // ---------------------------------------------------------------- consultas

    @Transactional(readOnly = true)
    public CompraDto.Response buscar(UUID id) {
        return resposta(carregar(id));
    }

    @Transactional(readOnly = true)
    public Page<CompraDto.Resumo> listar(Compra.Status status, Pageable pageable) {
        Page<Compra> pagina = status == null ? repository.findAll(pageable) : repository.findByStatus(status, pageable);
        return pagina.map(c -> new CompraDto.Resumo(c.getId(), c.getNumero(), c.getStatus(),
                fornecedores.nome(c.getFornecedorId()), c.getTotal(), c.getItens().size(), c.getCriadoEm(),
                c.getRecebidaEm()));
    }

    // ---------------------------------------------------------------- regras

    private void aplicar(Compra compra, CompraDto.Request req) {
        fornecedores.validarExistente(req.fornecedorId());
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(
                req.itens().stream().map(CompraDto.ItemRequest::produtoId).distinct().toList());
        List<CompraItem.Dados> itens = new ArrayList<>();
        for (CompraDto.ItemRequest i : req.itens()) {
            ProdutoResumo p = resumos.get(i.produtoId());
            if (p == null) {
                throw new NegocioException("PRODUTO_INVALIDO", "Produto não encontrado.");
            }
            if (!p.controlaEstoque()) {
                throw new NegocioException("PRODUTO_SEM_CONTROLE_ESTOQUE",
                        p.nome() + " não tem controle de estoque (prato preparado) e não entra em compras.");
            }
            var conversao = produtos.paraUnidadeEstoque(p.id(), i.quantidade(), i.unidadeId(), i.embalagemId());
            itens.add(new CompraItem.Dados(p.id(), p.nome(), i.quantidade(), i.unidadeId(), i.embalagemId(),
                    conversao.unidade(), conversao.quantidadeEstoque(), i.custoUnitario()));
        }
        compra.atualizar(req.fornecedorId(), req.observacao() == null || req.observacao().isBlank()
                ? null : req.observacao().trim(), itens);
    }

    CompraDto.Response resposta(Compra c) {
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(c.getItens().stream().map(CompraItem::getProdutoId).toList());
        return new CompraDto.Response(c.getId(), c.getNumero(), c.getStatus(), c.getFornecedorId(),
                fornecedores.nome(c.getFornecedorId()), c.getObservacao(), c.getTotal(), c.getCriadoEm(),
                c.getRecebidaEm(), c.getCanceladaEm(),
                c.getItens().stream().map(i -> new CompraDto.ItemResponse(i.getProdutoId(), i.getProdutoNome(),
                        i.getQuantidade(), i.getUnidadeId(), i.getEmbalagemId(), i.getUnidadeCompra(),
                        i.getQuantidadeEstoque(),
                        resumos.containsKey(i.getProdutoId()) ? resumos.get(i.getProdutoId()).unidadeSigla() : "",
                        i.getCustoUnitario(), i.getCustoTotal())).toList());
    }

    Compra carregar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Compra", id));
    }

    private static String texto(BigDecimal valor) {
        return valor.stripTrailingZeros().toPlainString();
    }
}
