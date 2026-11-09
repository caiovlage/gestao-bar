package br.com.bar.gestao.pedido.application;

import br.com.bar.gestao.catalogo.application.ProdutoConsultaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService.ProdutoResumo;
import br.com.bar.gestao.estoque.application.EstoqueService;
import br.com.bar.gestao.pedido.api.dto.PedidoDto;
import br.com.bar.gestao.pedido.domain.Pedido;
import br.com.bar.gestao.pedido.domain.PedidoItem;
import br.com.bar.gestao.pedido.domain.PedidoRepository;
import br.com.bar.gestao.shared.api.PageResponse;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import br.com.bar.gestao.venda.api.dto.VendaDto;
import br.com.bar.gestao.venda.application.VendaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Ciclo de vida do pedido do cardápio digital:
 * <pre>
 * RECEBIDO ──aceitar──► ACEITO ─► EM_PREPARO ─► PRONTO ─► ENTREGUE
 *     │                    │  (reserva o estoque dos produtos controlados)
 *     └──recusar/cancelar──┴──► CANCELADO (libera a reserva)
 * pagar (a partir do aceite): libera a reserva e gera a venda (que baixa o estoque) → PAGO
 * </pre>
 * O estoque só é reservado no aceite, para que pedidos falsos não bloqueiem produtos.
 */
@Service
public class PedidoService {

    private static final Logger log = LoggerFactory.getLogger(PedidoService.class);

    private final PedidoRepository repository;
    private final CardapioService cardapio;
    private final LimitePedidos limite;
    private final ProdutoConsultaService produtos;
    private final EstoqueService estoqueService;
    private final VendaService vendaService;

    public PedidoService(PedidoRepository repository, CardapioService cardapio, LimitePedidos limite,
                         ProdutoConsultaService produtos, EstoqueService estoqueService, VendaService vendaService) {
        this.repository = repository;
        this.cardapio = cardapio;
        this.limite = limite;
        this.produtos = produtos;
        this.estoqueService = estoqueService;
        this.vendaService = vendaService;
    }

    // ---------------------------------------------------------------- cliente

    @Transactional
    public PedidoDto.Acompanhamento criar(PedidoDto.CriarRequest req, String ipOrigem) {
        Optional<Pedido> existente = repository.findByChaveIdempotencia(req.chaveIdempotencia());
        if (existente.isPresent()) {
            log.info("Pedido reenviado (idempotência): nº {}", existente.get().getNumero());
            return PedidoDto.Acompanhamento.of(existente.get());
        }
        if (!cardapio.aberto()) {
            throw new NegocioException("CARDAPIO_FECHADO", "No momento não estamos recebendo pedidos pelo cardápio.");
        }
        limite.registrar(ipOrigem);

        Map<UUID, CardapioService.ItemDisponivel> disponiveis = cardapio.disponiveis(
                req.itens().stream().map(PedidoDto.ItemRequest::produtoId).distinct().toList());
        Pedido pedido = new Pedido(repository.proximoNumero(), req.chaveIdempotencia(), req.clienteNome().trim(),
                req.bloco().trim(), req.apartamento().trim(), texto(req.observacao()), ipOrigem);
        for (PedidoDto.ItemRequest item : req.itens()) {
            CardapioService.ItemDisponivel p = disponiveis.get(item.produtoId());
            if (p == null) {
                throw new NegocioException("PRODUTO_INDISPONIVEL",
                        "Um dos itens não está mais disponível no cardápio. Atualize o cardápio e tente novamente.");
            }
            if (p.esgotado()) {
                throw new NegocioException("PRODUTO_ESGOTADO", p.nome() + " está esgotado no momento.");
            }
            pedido.adicionarItem(p.id(), p.nome(), item.quantidade(), p.preco(), texto(item.observacao()));
        }
        repository.save(pedido);
        log.info("Pedido nº {} recebido do cardápio: entrega={} total={} itens={}", pedido.getNumero(),
                pedido.getLocal(), pedido.getTotal(), pedido.getItens().size());
        return PedidoDto.Acompanhamento.of(pedido);
    }

    @Transactional(readOnly = true)
    public PedidoDto.Acompanhamento acompanhar(UUID id) {
        return PedidoDto.Acompanhamento.of(carregar(id));
    }

    // ---------------------------------------------------------------- painel

    @Transactional(readOnly = true)
    public List<PedidoDto.Detalhe> emAndamento() {
        return repository.emAndamento(Pedido.StatusPreparo.CANCELADO, Pedido.StatusPreparo.ENTREGUE,
                Pedido.StatusFinanceiro.PAGO).stream().map(PedidoDto.Detalhe::of).toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<PedidoDto.Detalhe> historico(Pageable pageable) {
        return PageResponse.of(repository.findAllByOrderByCriadoEmDesc(pageable), PedidoDto.Detalhe::of);
    }

    @Transactional(readOnly = true)
    public PedidoDto.Detalhe buscar(UUID id) {
        return PedidoDto.Detalhe.of(carregar(id));
    }

    /** Aceita e reserva o estoque dos produtos controlados. Sem saldo, o aceite falha e nada muda. */
    @Transactional
    public PedidoDto.Detalhe aceitar(UUID id) {
        Pedido pedido = travar(id);
        if (pedido.getStatusPreparo() != Pedido.StatusPreparo.RECEBIDO) {
            pedido.aceitar(false); // lança a mensagem de status inválido
        }
        List<EstoqueService.Reserva> reservas = reservas(pedido);
        estoqueService.reservar(reservas);
        pedido.aceitar(!reservas.isEmpty());
        log.info("Pedido nº {} aceito (reservas: {})", pedido.getNumero(), reservas.size());
        return PedidoDto.Detalhe.of(pedido);
    }

    @Transactional
    public PedidoDto.Detalhe avancar(UUID id, Pedido.StatusPreparo status) {
        Pedido pedido = travar(id);
        pedido.avancar(status);
        log.info("Pedido nº {} → {}", pedido.getNumero(), status);
        return PedidoDto.Detalhe.of(pedido);
    }

    /** Recusa (antes do aceite) ou cancela, liberando a reserva de estoque. */
    @Transactional
    public PedidoDto.Detalhe cancelar(UUID id, String motivo) {
        Pedido pedido = travar(id);
        boolean tinhaReserva = pedido.isEstoqueReservado();
        pedido.cancelar(motivo.trim());
        if (tinhaReserva) {
            estoqueService.liberar(reservas(pedido));
        }
        log.info("Pedido nº {} cancelado: {}", pedido.getNumero(), motivo);
        return PedidoDto.Detalhe.of(pedido);
    }

    /**
     * Registra o pagamento presencial: libera a reserva e gera a venda no caixa aberto, com os preços
     * do pedido (a venda baixa o estoque). O pedido fica travado durante a operação e a venda usa o
     * id do pedido como chave de idempotência — um pedido nunca gera duas vendas.
     */
    @Transactional
    public PedidoDto.Detalhe pagar(UUID id, PedidoDto.PagarRequest req) {
        Pedido pedido = travar(id);
        pedido.exigirPagavel();
        if (pedido.isEstoqueReservado()) {
            estoqueService.liberar(reservas(pedido));
        }
        List<VendaDto.ItemRequest> itens = pedido.getItens().stream()
                .map(i -> new VendaDto.ItemRequest(i.getProdutoId(), BigDecimal.valueOf(i.getQuantidade())))
                .toList();
        Map<UUID, BigDecimal> precos = pedido.getItens().stream()
                .collect(Collectors.toMap(PedidoItem::getProdutoId, PedidoItem::getPrecoUnitario, (a, b) -> a));
        VendaDto.Detalhe venda = vendaService.registrarDoPedido(pedido.getId(), new VendaDto.RegistrarRequest(
                pedido.getId(), itens, req.desconto(), req.descontoPercentual(), req.formaPagamento(),
                req.valorRecebido(), "Pedido nº " + pedido.getNumero() + " — " + pedido.getLocal()), precos);
        pedido.marcarPago(venda.id());
        log.info("Pedido nº {} pago: venda nº {}", pedido.getNumero(), venda.numero());
        return PedidoDto.Detalhe.of(pedido);
    }

    // ---------------------------------------------------------------- interno

    /** Quantidade por produto com controle de estoque (itens repetidos somados). */
    private List<EstoqueService.Reserva> reservas(Pedido pedido) {
        Map<UUID, Integer> quantidades = new LinkedHashMap<>();
        pedido.getItens().forEach(i -> quantidades.merge(i.getProdutoId(), i.getQuantidade(), Integer::sum));
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(quantidades.keySet());
        return quantidades.entrySet().stream()
                .filter(e -> resumos.containsKey(e.getKey()) && resumos.get(e.getKey()).controlaEstoque())
                .map(e -> {
                    ProdutoResumo p = resumos.get(e.getKey());
                    return new EstoqueService.Reserva(p.id(), p.nome(), p.unidadeSigla(), BigDecimal.valueOf(e.getValue()));
                })
                .toList();
    }

    private Pedido carregar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Pedido", id));
    }

    private Pedido travar(UUID id) {
        return repository.travar(id).orElseThrow(() -> new RecursoNaoEncontradoException("Pedido", id));
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
