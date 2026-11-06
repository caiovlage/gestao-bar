package br.com.bar.gestao.venda.application;

import br.com.bar.gestao.caixa.application.CaixaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService.ProdutoResumo;
import br.com.bar.gestao.estoque.application.EstoqueService;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import br.com.bar.gestao.venda.api.dto.VendaDto;
import br.com.bar.gestao.venda.domain.Venda;
import br.com.bar.gestao.venda.domain.VendaItem;
import br.com.bar.gestao.venda.domain.VendaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Registro e cancelamento de vendas. Tudo numa única transação: caixa aberto (travado),
 * preço e custo congelados, baixa de estoque dos produtos controlados e gravação da venda.
 * Qualquer falha (ex.: estoque insuficiente) desfaz tudo.
 */
@Service
public class VendaService {

    private static final Logger log = LoggerFactory.getLogger(VendaService.class);

    private final VendaRepository repository;
    private final CaixaService caixaService;
    private final ProdutoConsultaService produtos;
    private final EstoqueService estoqueService;

    public VendaService(VendaRepository repository, CaixaService caixaService, ProdutoConsultaService produtos,
                        EstoqueService estoqueService) {
        this.repository = repository;
        this.caixaService = caixaService;
        this.produtos = produtos;
        this.estoqueService = estoqueService;
    }

    @Transactional
    public VendaDto.Detalhe registrar(VendaDto.RegistrarRequest req) {
        return registrar(req, null, Map.of());
    }

    /**
     * Venda gerada a partir de um pedido do cardápio: usa os preços do pedido (o que o cliente viu)
     * e referencia o pedido de origem. A restrição única em venda.pedido_id impede duas vendas.
     */
    @Transactional
    public VendaDto.Detalhe registrarDoPedido(UUID pedidoId, VendaDto.RegistrarRequest req, Map<UUID, BigDecimal> precos) {
        return registrar(req, pedidoId, precos);
    }

    private VendaDto.Detalhe registrar(VendaDto.RegistrarRequest req, UUID pedidoId, Map<UUID, BigDecimal> precosPedido) {
        // Reenvio da mesma venda (duplo clique, rede instável): devolve a já registrada.
        Optional<Venda> existente = repository.findByChaveIdempotencia(req.chaveIdempotencia());
        if (existente.isPresent()) {
            log.info("Venda reenviada (idempotência): nº {}", existente.get().getNumero());
            return VendaDto.Detalhe.of(existente.get());
        }

        UUID caixaId = caixaService.travarCaixaAberto();
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(
                req.itens().stream().map(VendaDto.ItemRequest::produtoId).distinct().toList());

        Venda venda = new Venda(repository.proximoNumero(), req.chaveIdempotencia(), caixaId, req.formaPagamento(),
                texto(req.observacao()));
        venda.vincularPedido(pedidoId);
        BigDecimal subtotal = BigDecimal.ZERO;
        BigDecimal custoTotal = BigDecimal.ZERO;
        List<EstoqueService.Movimento> baixas = new ArrayList<>();

        for (VendaDto.ItemRequest item : req.itens()) {
            ProdutoResumo p = resumos.get(item.produtoId());
            if (p == null) {
                throw new NegocioException("PRODUTO_INVALIDO", "Produto não encontrado.");
            }
            BigDecimal preco = precosPedido.get(p.id());
            if (preco == null) {
                // Venda direta do PDV: produto precisa estar à venda agora. Pedido aceito já foi prometido ao cliente.
                if (!p.ativo() || !p.vendavel()) {
                    throw new NegocioException("PRODUTO_INDISPONIVEL", p.nome() + " não está disponível para venda.");
                }
                if (p.precoVenda() == null) {
                    throw new NegocioException("PRODUTO_SEM_PRECO", p.nome() + " não tem preço de venda cadastrado.");
                }
                preco = p.precoVigente();
            }
            BigDecimal total = VendaCalculo.valor(preco, item.quantidade());
            BigDecimal custo = VendaCalculo.valor(p.custoMedio(), item.quantidade());
            venda.adicionarItem(p.id(), p.nome(), item.quantidade(), preco, p.custoMedio(), total, custo,
                    p.controlaEstoque());
            subtotal = subtotal.add(total);
            custoTotal = custoTotal.add(custo);
            if (p.controlaEstoque()) {
                baixas.add(new EstoqueService.Movimento(p.id(), p.nome(), p.unidadeSigla(), TipoMovimentacao.SAIDA_VENDA,
                        item.quantidade().negate(), p.custoMedio(), null, OrigemMovimentacao.VENDA, venda.getId(),
                        "Venda nº " + venda.getNumero()));
            }
        }

        BigDecimal desconto = VendaCalculo.desconto(subtotal, req.desconto(), req.descontoPercentual());
        var recebimento = VendaCalculo.recebimento(req.formaPagamento(), subtotal.subtract(desconto), req.valorRecebido());
        venda.definirValores(subtotal, desconto, custoTotal, recebimento.valorRecebido(), recebimento.troco());

        estoqueService.movimentar(baixas);
        repository.save(venda);
        log.info("Venda nº {} registrada: total={} forma={} itens={}", venda.getNumero(), venda.getTotal(),
                venda.getFormaPagamento(), venda.getItens().size());
        return VendaDto.Detalhe.of(venda);
    }

    /** Cancela com justificativa, estornando o estoque. Só enquanto o caixa da venda estiver aberto. */
    @Transactional
    public VendaDto.Detalhe cancelar(UUID id, String motivo) {
        Venda venda = repository.travar(id).orElseThrow(() -> new RecursoNaoEncontradoException("Venda", id));
        if (venda.getStatus() == Venda.Status.CANCELADA) {
            throw new NegocioException("VENDA_JA_CANCELADA", "A venda nº " + venda.getNumero() + " já está cancelada.");
        }
        caixaService.exigirAberto(venda.getCaixaId(),
                "O caixa desta venda já foi fechado. Corrija o estoque por ajuste, se necessário.");

        List<UUID> controlados = venda.getItens().stream().filter(VendaItem::isControlaEstoque)
                .map(VendaItem::getProdutoId).distinct().toList();
        Map<UUID, ProdutoResumo> resumos = produtos.resumos(controlados);
        List<EstoqueService.Movimento> estornos = venda.getItens().stream()
                .filter(VendaItem::isControlaEstoque)
                .map(i -> {
                    ProdutoResumo p = resumos.get(i.getProdutoId());
                    return new EstoqueService.Movimento(i.getProdutoId(), i.getProdutoNome(),
                            p == null ? "" : p.unidadeSigla(), TipoMovimentacao.ESTORNO_VENDA, i.getQuantidade(),
                            i.getCustoUnitario(), null, OrigemMovimentacao.VENDA, venda.getId(),
                            "Cancelamento da venda nº " + venda.getNumero());
                })
                .toList();
        estoqueService.movimentar(estornos);
        venda.cancelar(motivo.trim());
        log.info("Venda nº {} cancelada: {}", venda.getNumero(), motivo);
        return VendaDto.Detalhe.of(venda);
    }

    @Transactional(readOnly = true)
    public VendaDto.Detalhe buscar(UUID id) {
        return VendaDto.Detalhe.of(repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Venda", id)));
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
