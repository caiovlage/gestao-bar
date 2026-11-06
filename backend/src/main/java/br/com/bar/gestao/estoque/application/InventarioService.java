package br.com.bar.gestao.estoque.application;

import br.com.bar.gestao.catalogo.application.ProdutoConsultaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService.ProdutoResumo;
import br.com.bar.gestao.estoque.api.dto.InventarioDto;
import br.com.bar.gestao.estoque.domain.Inventario;
import br.com.bar.gestao.estoque.domain.InventarioItem;
import br.com.bar.gestao.estoque.domain.InventarioRepository;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
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
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Inventário (contagem física). Regras:
 * <ul>
 *   <li>apenas um inventário aberto por vez;</li>
 *   <li>contagens podem ser salvas aos poucos; itens não contados são ignorados na conclusão;</li>
 *   <li>na conclusão, a diferença é calculada contra o saldo do sistema naquele instante
 *       e gera um ajuste (AJUSTE_INVENTARIO) por item divergente.</li>
 * </ul>
 */
@Service
public class InventarioService {

    private static final Logger log = LoggerFactory.getLogger(InventarioService.class);

    private final InventarioRepository repository;
    private final EstoqueService estoqueService;
    private final ProdutoConsultaService produtos;

    public InventarioService(InventarioRepository repository, EstoqueService estoqueService,
                             ProdutoConsultaService produtos) {
        this.repository = repository;
        this.estoqueService = estoqueService;
        this.produtos = produtos;
    }

    @Transactional(readOnly = true)
    public Page<InventarioDto.ResumoResponse> listar(Pageable pageable) {
        return repository.findAll(pageable).map(i -> new InventarioDto.ResumoResponse(i.getId(), i.getDescricao(),
                nomeCategoria(i), i.getStatus(), i.getItens().size(),
                (int) i.getItens().stream().filter(InventarioItem::isContado).count(),
                i.getCriadoEm(), i.getConcluidoEm(), i.getCanceladoEm()));
    }

    @Transactional
    public InventarioDto.DetalheResponse criar(InventarioDto.CriarRequest req) {
        if (repository.existsByStatus(Inventario.Status.ABERTO)) {
            throw new NegocioException("INVENTARIO_EM_ANDAMENTO",
                    "Já existe um inventário em andamento. Conclua ou cancele antes de abrir outro.");
        }
        List<UUID> ids = produtos.idsAtivos(req.categoriaId());
        if (ids.isEmpty()) {
            throw new NegocioException("INVENTARIO_SEM_PRODUTOS", "Não há produtos ativos para inventariar.");
        }
        Inventario inventario = repository.saveAndFlush(new Inventario(req.descricao().trim(), req.categoriaId(), ids));
        log.info("Inventário aberto: id={} itens={}", inventario.getId(), ids.size());
        return detalhe(inventario);
    }

    @Transactional(readOnly = true)
    public InventarioDto.DetalheResponse buscar(UUID id) {
        return detalhe(carregar(id));
    }

    @Transactional
    public InventarioDto.DetalheResponse registrarContagens(UUID id, InventarioDto.ContagensRequest req) {
        Inventario inventario = carregar(id);
        inventario.exigirAberto();
        Map<UUID, InventarioItem> itens = itensPorProduto(inventario);
        for (InventarioDto.Contagem c : req.contagens()) {
            InventarioItem item = itens.get(c.produtoId());
            if (item == null) {
                throw new NegocioException("PRODUTO_FORA_DO_INVENTARIO", "Produto não faz parte deste inventário.");
            }
            item.registrarContagem(c.quantidadeContada());
        }
        return detalhe(inventario);
    }

    @Transactional
    public InventarioDto.DetalheResponse concluir(UUID id, InventarioDto.EncerrarRequest req) {
        Inventario inventario = carregar(id);
        inventario.exigirAberto();
        List<InventarioItem> contados = inventario.getItens().stream().filter(InventarioItem::isContado).toList();
        if (contados.isEmpty()) {
            throw new NegocioException("INVENTARIO_SEM_CONTAGEM", "Nenhum item foi contado. Registre as contagens antes de concluir.");
        }
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(contados.stream().map(InventarioItem::getProdutoId).toList());
        String observacao = "Inventário: " + inventario.getDescricao();

        List<EstoqueService.ResultadoAjuste> resultados = estoqueService.ajustarPara(contados.stream()
                .map(item -> new EstoqueService.AjusteAlvo(item.getProdutoId(), item.getQuantidadeContada(),
                        custo(resumos.get(item.getProdutoId())), OrigemMovimentacao.INVENTARIO,
                        inventario.getId(), observacao))
                .toList());

        Map<UUID, InventarioItem> itens = itensPorProduto(inventario);
        long ajustados = 0;
        for (EstoqueService.ResultadoAjuste r : resultados) {
            itens.get(r.produtoId()).registrarResultado(r.saldoAnterior(), r.diferenca(),
                    r.movimentacao() == null ? null : r.movimentacao().getId());
            if (r.movimentacao() != null) ajustados++;
        }
        inventario.concluir(texto(req == null ? null : req.observacao()));
        log.info("Inventário concluído: id={} contados={} ajustados={}", id, contados.size(), ajustados);
        return detalhe(inventario);
    }

    @Transactional
    public InventarioDto.DetalheResponse cancelar(UUID id, InventarioDto.EncerrarRequest req) {
        Inventario inventario = carregar(id);
        inventario.cancelar(texto(req == null ? null : req.observacao()));
        log.info("Inventário cancelado: id={}", id);
        return detalhe(inventario);
    }

    // ---------------------------------------------------------------- montagem da resposta

    private InventarioDto.DetalheResponse detalhe(Inventario inv) {
        List<UUID> ids = inv.getItens().stream().map(InventarioItem::getProdutoId).toList();
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(ids);
        boolean aberto = inv.getStatus() == Inventario.Status.ABERTO;
        Map<UUID, BigDecimal> saldos = aberto ? estoqueService.quantidades(ids) : Map.of();

        List<InventarioDto.ItemResponse> itens = inv.getItens().stream().map(item -> {
            ProdutoResumo p = resumos.get(item.getProdutoId());
            BigDecimal sistema = aberto ? saldos.getOrDefault(item.getProdutoId(), BigDecimal.ZERO) : item.getQuantidadeSistema();
            BigDecimal diferenca = aberto
                    ? (item.isContado() ? item.getQuantidadeContada().subtract(sistema) : null)
                    : item.getDiferenca();
            BigDecimal custo = custo(p);
            BigDecimal valor = diferenca == null ? null : diferenca.multiply(custo).setScale(2, RoundingMode.HALF_UP);
            return new InventarioDto.ItemResponse(item.getProdutoId(), p == null ? "?" : p.nome(),
                    p == null ? null : p.categoriaNome(), p == null ? "" : p.unidadeSigla(), sistema,
                    item.getQuantidadeContada(), diferenca, custo, valor);
        }).sorted(Comparator.comparing((InventarioDto.ItemResponse i) -> i.categoria() == null ? "~" : i.categoria())
                .thenComparing(i -> i.produtoNome().toLowerCase())).toList();

        int contados = (int) itens.stream().filter(i -> i.quantidadeContada() != null).count();
        int divergentes = (int) itens.stream().filter(i -> i.diferenca() != null && i.diferenca().signum() != 0).count();
        return new InventarioDto.DetalheResponse(inv.getId(), inv.getDescricao(), nomeCategoria(inv),
                inv.getStatus(), inv.getObservacao(), inv.getCriadoEm(), inv.getConcluidoEm(), inv.getCanceladoEm(),
                itens.size(), contados, divergentes, itens);
    }

    private String nomeCategoria(Inventario inv) {
        return inv.getCategoriaId() == null ? null : produtos.nomeCategoria(inv.getCategoriaId());
    }

    private static Map<UUID, InventarioItem> itensPorProduto(Inventario inv) {
        return inv.getItens().stream().collect(Collectors.toMap(InventarioItem::getProdutoId, Function.identity()));
    }

    private static BigDecimal custo(ProdutoResumo p) {
        return p == null ? BigDecimal.ZERO : p.custoMedio();
    }

    private Inventario carregar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Inventário", id));
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
