package br.com.bar.gestao.comanda.application;

import br.com.bar.gestao.caixa.application.CaixaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService;
import br.com.bar.gestao.catalogo.application.ProdutoConsultaService.ProdutoResumo;
import br.com.bar.gestao.comanda.api.dto.ComandaDto;
import br.com.bar.gestao.comanda.domain.Comanda;
import br.com.bar.gestao.comanda.domain.ComandaItem;
import br.com.bar.gestao.comanda.domain.ComandaRepository;
import br.com.bar.gestao.estoque.application.EstoqueService;
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
import java.util.List;
import java.util.UUID;

/**
 * Comandas (contas abertas). Ciclo:
 * <pre>
 * abrir (caixa aberto) → lançar/retirar itens (reserva/libera estoque) → fechar (venda no caixa) | cancelar
 * </pre>
 * A comanda pertence ao caixa em que foi aberta; o caixa só fecha depois de todas as suas comandas.
 */
@Service
public class ComandaService {

    private static final Logger log = LoggerFactory.getLogger(ComandaService.class);

    private final ComandaRepository repository;
    private final CaixaService caixaService;
    private final ProdutoConsultaService produtos;
    private final EstoqueService estoqueService;
    private final VendaService vendaService;

    public ComandaService(ComandaRepository repository, CaixaService caixaService, ProdutoConsultaService produtos,
                          EstoqueService estoqueService, VendaService vendaService) {
        this.repository = repository;
        this.caixaService = caixaService;
        this.produtos = produtos;
        this.estoqueService = estoqueService;
        this.vendaService = vendaService;
    }

    @Transactional
    public ComandaDto.Detalhe abrir(ComandaDto.AbrirRequest req) {
        UUID caixaId = caixaService.travarCaixaAberto();
        Comanda comanda = repository.save(new Comanda(repository.proximoNumero(), caixaId, req.clienteNome().trim(),
                texto(req.local()), texto(req.observacao())));
        log.info("Comanda nº {} aberta: {} {}", comanda.getNumero(), comanda.getClienteNome(),
                comanda.getLocal() == null ? "" : comanda.getLocal());
        return ComandaDto.Detalhe.of(comanda);
    }

    @Transactional
    public ComandaDto.Detalhe alterar(UUID id, ComandaDto.AbrirRequest req) {
        Comanda comanda = travar(id);
        comanda.alterarIdentificacao(req.clienteNome().trim(), texto(req.local()), texto(req.observacao()));
        return ComandaDto.Detalhe.of(comanda);
    }

    /** Lança um produto pelo preço de hoje; produtos com controle de estoque têm a quantidade reservada. */
    @Transactional
    public ComandaDto.Detalhe lancar(UUID id, ComandaDto.LancarRequest req) {
        Comanda comanda = travar(id);
        comanda.exigirAberta();
        ProdutoResumo p = produtos.resumo(req.produtoId());
        if (!p.ativo() || !p.vendavel()) {
            throw new NegocioException("PRODUTO_INDISPONIVEL", p.nome() + " não está disponível para venda.");
        }
        if (p.precoVigente() == null) {
            throw new NegocioException("PRODUTO_SEM_PRECO", p.nome() + " não tem preço de venda cadastrado.");
        }
        if (p.controlaEstoque()) {
            estoqueService.reservar(List.of(new EstoqueService.Reserva(p.id(), p.nome(), p.unidadeSigla(),
                    req.quantidade())));
        }
        comanda.lancar(p.id(), p.nome(), req.quantidade(), p.precoVigente(), texto(req.observacao()),
                p.controlaEstoque());
        log.info("Comanda nº {}: + {} {}", comanda.getNumero(), req.quantidade().stripTrailingZeros().toPlainString(),
                p.nome());
        return ComandaDto.Detalhe.of(comanda);
    }

    /** Retira unidades (ou a linha inteira) e devolve a reserva de estoque correspondente. */
    @Transactional
    public ComandaDto.Detalhe retirar(UUID id, UUID itemId, BigDecimal quantidade) {
        Comanda comanda = travar(id);
        ComandaItem item = comanda.item(itemId);
        boolean controla = item.isControlaEstoque();
        UUID produtoId = item.getProdutoId();
        String nome = item.getProdutoNome();
        BigDecimal retirada = comanda.retirar(itemId, quantidade);
        if (controla) {
            estoqueService.liberar(List.of(new EstoqueService.Reserva(produtoId, nome, "", retirada)));
        }
        log.info("Comanda nº {}: − {} {}", comanda.getNumero(), retirada.stripTrailingZeros().toPlainString(), nome);
        return ComandaDto.Detalhe.of(comanda);
    }

    /**
     * Fecha a conta: libera as reservas e gera a venda (que baixa o estoque) no caixa aberto, com os
     * preços lançados. A comanda fica travada e a venda usa o id dela como chave de idempotência.
     */
    @Transactional
    public ComandaDto.Detalhe fechar(UUID id, ComandaDto.FecharRequest req) {
        Comanda comanda = travar(id);
        comanda.exigirAberta();
        if (comanda.getItens().isEmpty()) {
            throw new NegocioException("COMANDA_VAZIA", "A comanda nº " + comanda.getNumero()
                    + " não tem itens. Cancele-a se não for usada.");
        }
        estoqueService.liberar(reservas(comanda));
        List<VendaDto.ItemRequest> itens = comanda.getItens().stream()
                .map(i -> new VendaDto.ItemRequest(i.getProdutoId(), i.getQuantidade())).toList();
        List<BigDecimal> precos = comanda.getItens().stream().map(ComandaItem::getPrecoUnitario).toList();
        String obs = "Comanda nº " + comanda.getNumero() + " — " + comanda.getClienteNome()
                + (comanda.getLocal() == null ? "" : " · " + comanda.getLocal());
        VendaDto.Detalhe venda = vendaService.registrarDaComanda(comanda.getId(), new VendaDto.RegistrarRequest(
                comanda.getId(), itens, req.desconto(), req.descontoPercentual(), req.formaPagamento(),
                req.valorRecebido(), obs.length() > 500 ? obs.substring(0, 500) : obs), precos);
        comanda.fechar(venda.id());
        log.info("Comanda nº {} fechada: venda nº {} total={}", comanda.getNumero(), venda.numero(), venda.total());
        return ComandaDto.Detalhe.of(comanda);
    }

    @Transactional
    public ComandaDto.Detalhe cancelar(UUID id, String motivo) {
        Comanda comanda = travar(id);
        comanda.exigirAberta();
        estoqueService.liberar(reservas(comanda));
        comanda.cancelar(motivo.trim());
        log.info("Comanda nº {} cancelada: {}", comanda.getNumero(), motivo);
        return ComandaDto.Detalhe.of(comanda);
    }

    @Transactional(readOnly = true)
    public List<ComandaDto.Detalhe> abertas() {
        return repository.findByStatusOrderByCriadoEm(Comanda.Status.ABERTA).stream().map(ComandaDto.Detalhe::of).toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<ComandaDto.Detalhe> historico(Pageable pageable) {
        return PageResponse.of(repository.findByStatusNotOrderByCriadoEmDesc(Comanda.Status.ABERTA, pageable),
                ComandaDto.Detalhe::of);
    }

    @Transactional(readOnly = true)
    public ComandaDto.Detalhe buscar(UUID id) {
        return ComandaDto.Detalhe.of(repository.findById(id)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Comanda", id)));
    }

    // ---------------------------------------------------------------- interno

    private List<EstoqueService.Reserva> reservas(Comanda comanda) {
        return comanda.getItens().stream().filter(ComandaItem::isControlaEstoque)
                .map(i -> new EstoqueService.Reserva(i.getProdutoId(), i.getProdutoNome(), "", i.getQuantidade()))
                .toList();
    }

    private Comanda travar(UUID id) {
        return repository.travar(id).orElseThrow(() -> new RecursoNaoEncontradoException("Comanda", id));
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
