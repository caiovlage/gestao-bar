package br.com.bar.gestao.estoque.application;

import br.com.bar.gestao.configuracao.application.ConfiguracaoService;
import br.com.bar.gestao.estoque.domain.Estoque;
import br.com.bar.gestao.estoque.domain.EstoqueRepository;
import br.com.bar.gestao.estoque.domain.MovimentacaoEstoque;
import br.com.bar.gestao.estoque.domain.MovimentacaoEstoqueRepository;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Único ponto do sistema que altera o saldo de estoque.
 *
 * <p>Toda alteração: (1) bloqueia as linhas de saldo dos produtos envolvidos (SELECT ... FOR UPDATE,
 * sempre na mesma ordem), (2) valida sentido e saldo, (3) aplica e (4) grava a movimentação —
 * tudo na transação de quem chamou ({@code MANDATORY}). Se qualquer passo falhar, nada é gravado.
 */
@Service
public class EstoqueService {

    private static final Logger log = LoggerFactory.getLogger(EstoqueService.class);

    private final EstoqueRepository estoqueRepository;
    private final MovimentacaoEstoqueRepository movimentacaoRepository;
    private final ConfiguracaoService configuracao;

    public EstoqueService(EstoqueRepository estoqueRepository, MovimentacaoEstoqueRepository movimentacaoRepository,
                          ConfiguracaoService configuracao) {
        this.estoqueRepository = estoqueRepository;
        this.movimentacaoRepository = movimentacaoRepository;
        this.configuracao = configuracao;
    }

    /**
     * Pedido de movimentação. {@code quantidade} é positiva para entradas e negativa para saídas,
     * já na unidade de estoque. {@code produtoNome}/{@code unidadeSigla} servem às mensagens de erro.
     */
    public record Movimento(UUID produtoId, String produtoNome, String unidadeSigla, TipoMovimentacao tipo,
                            BigDecimal quantidade, BigDecimal custoUnitario, String quantidadeInformada,
                            OrigemMovimentacao origem, UUID origemId, String observacao) {
    }

    /** Ajuste para um saldo-alvo (contagem física). */
    public record AjusteAlvo(UUID produtoId, BigDecimal quantidadeAlvo, BigDecimal custoUnitario,
                             OrigemMovimentacao origem, UUID origemId, String observacao) {
    }

    /** Resultado de um ajuste: saldo do sistema no instante do ajuste e a movimentação gerada (se houve diferença). */
    public record ResultadoAjuste(UUID produtoId, BigDecimal saldoAnterior, BigDecimal diferenca,
                                  MovimentacaoEstoque movimentacao) {
    }

    // ---------------------------------------------------------------- escrita

    @Transactional(propagation = Propagation.MANDATORY)
    public void inicializar(UUID produtoId) {
        if (!estoqueRepository.existsById(produtoId)) {
            estoqueRepository.save(new Estoque(produtoId));
        }
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public MovimentacaoEstoque movimentar(Movimento movimento) {
        return movimentar(List.of(movimento)).getFirst();
    }

    /** Aplica várias movimentações atomicamente (ex.: todos os ingredientes de uma venda). */
    @Transactional(propagation = Propagation.MANDATORY)
    public List<MovimentacaoEstoque> movimentar(List<Movimento> movimentos) {
        if (movimentos.isEmpty()) {
            return List.of();
        }
        Map<UUID, Estoque> saldos = travar(movimentos.stream().map(Movimento::produtoId).toList());
        boolean permitirNegativo = configuracao.ativo(ConfiguracaoService.PERMITIR_ESTOQUE_NEGATIVO);

        List<MovimentacaoEstoque> gravadas = new ArrayList<>();
        for (Movimento m : movimentos) {
            validarSentido(m);
            Estoque saldo = saldos.get(m.produtoId());
            if (m.tipo().sentido() == TipoMovimentacao.Sentido.SAIDA && !permitirNegativo
                    && saldo.getDisponivel().add(m.quantidade()).signum() < 0) {
                throw new NegocioException("ESTOQUE_INSUFICIENTE", "Estoque insuficiente de " + m.produtoNome()
                        + ": disponível " + texto(saldo.getDisponivel()) + " " + m.unidadeSigla()
                        + ", necessário " + texto(m.quantidade().negate()) + " " + m.unidadeSigla() + ".");
            }
            gravadas.add(registrar(saldo, m.tipo(), m.quantidade(), m.custoUnitario(), m.quantidadeInformada(),
                    m.origem(), m.origemId(), m.observacao()));
        }
        return gravadas;
    }

    /**
     * Ajusta cada produto para a quantidade-alvo (contagem física). A diferença é calculada sobre o
     * saldo travado no momento do ajuste, então vendas registradas durante a contagem não se perdem.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public List<ResultadoAjuste> ajustarPara(List<AjusteAlvo> alvos) {
        if (alvos.isEmpty()) {
            return List.of();
        }
        Map<UUID, Estoque> saldos = travar(alvos.stream().map(AjusteAlvo::produtoId).toList());
        List<ResultadoAjuste> resultados = new ArrayList<>();
        for (AjusteAlvo alvo : alvos) {
            if (alvo.quantidadeAlvo().signum() < 0) {
                throw new NegocioException("QUANTIDADE_INVALIDA", "A quantidade contada não pode ser negativa.");
            }
            Estoque saldo = saldos.get(alvo.produtoId());
            BigDecimal anterior = saldo.getQuantidade();
            BigDecimal diferenca = alvo.quantidadeAlvo().subtract(anterior);
            MovimentacaoEstoque mov = diferenca.signum() == 0 ? null
                    : registrar(saldo, TipoMovimentacao.AJUSTE_INVENTARIO, diferenca, alvo.custoUnitario(), null,
                    alvo.origem(), alvo.origemId(), alvo.observacao());
            resultados.add(new ResultadoAjuste(alvo.produtoId(), anterior, diferenca, mov));
        }
        return resultados;
    }

    /** Item a reservar/liberar (na unidade de estoque). */
    public record Reserva(UUID produtoId, String produtoNome, String unidadeSigla, BigDecimal quantidade) {
    }

    /**
     * Reserva estoque para um pedido aceito: o saldo não muda, mas o disponível diminui, então
     * o PDV não consegue vender o que já foi prometido ao cliente.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public void reservar(List<Reserva> reservas) {
        if (reservas.isEmpty()) return;
        Map<UUID, Estoque> saldos = travar(reservas.stream().map(Reserva::produtoId).toList());
        boolean permitirNegativo = configuracao.ativo(ConfiguracaoService.PERMITIR_ESTOQUE_NEGATIVO);
        for (Reserva r : reservas) {
            Estoque saldo = saldos.get(r.produtoId());
            if (!permitirNegativo && saldo.getDisponivel().compareTo(r.quantidade()) < 0) {
                throw new NegocioException("ESTOQUE_INSUFICIENTE", "Estoque insuficiente de " + r.produtoNome()
                        + ": disponível " + texto(saldo.getDisponivel()) + " " + r.unidadeSigla()
                        + ", pedido " + texto(r.quantidade()) + " " + r.unidadeSigla() + ".");
            }
            saldo.reservar(r.quantidade());
        }
        log.info("Estoque reservado: {} item(ns)", reservas.size());
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void liberar(List<Reserva> reservas) {
        if (reservas.isEmpty()) return;
        Map<UUID, Estoque> saldos = travar(reservas.stream().map(Reserva::produtoId).toList());
        for (Reserva r : reservas) {
            saldos.get(r.produtoId()).liberar(r.quantidade());
        }
        log.info("Reserva de estoque liberada: {} item(ns)", reservas.size());
    }

    // ---------------------------------------------------------------- leitura

    @Transactional(readOnly = true)
    public BigDecimal quantidade(UUID produtoId) {
        return estoqueRepository.findById(produtoId).map(Estoque::getQuantidade).orElse(BigDecimal.ZERO);
    }

    @Transactional(readOnly = true)
    public Map<UUID, BigDecimal> quantidades(Collection<UUID> produtoIds) {
        return estoqueRepository.findAllById(produtoIds).stream()
                .collect(Collectors.toMap(Estoque::getProdutoId, Estoque::getQuantidade));
    }

    @Transactional(readOnly = true)
    public boolean possuiMovimentacoes(UUID produtoId) {
        return movimentacaoRepository.existsByProdutoId(produtoId);
    }

    // ---------------------------------------------------------------- interno

    private MovimentacaoEstoque registrar(Estoque saldo, TipoMovimentacao tipo, BigDecimal quantidade,
                                          BigDecimal custoUnitario, String quantidadeInformada,
                                          OrigemMovimentacao origem, UUID origemId, String observacao) {
        BigDecimal anterior = saldo.getQuantidade();
        saldo.aplicar(quantidade);
        MovimentacaoEstoque mov = movimentacaoRepository.save(new MovimentacaoEstoque(saldo.getProdutoId(), tipo,
                quantidade, anterior, custoUnitario, quantidadeInformada, origem, origemId, observacao));
        log.info("Estoque: {} {} produto={} {} → {} (origem {} {})", tipo, texto(quantidade), saldo.getProdutoId(),
                texto(anterior), texto(saldo.getQuantidade()), origem, origemId == null ? "" : origemId);
        return mov;
    }

    /** Trava os saldos em ordem crescente de produto_id (mesma ordem em todas as transações → sem deadlock). */
    private Map<UUID, Estoque> travar(Collection<UUID> produtoIds) {
        List<UUID> ids = new ArrayList<>(new TreeSet<>(produtoIds));
        Map<UUID, Estoque> saldos = estoqueRepository.travar(ids).stream()
                .collect(Collectors.toMap(Estoque::getProdutoId, Function.identity(), (a, b) -> a, LinkedHashMap::new));
        for (UUID id : ids) {
            if (!saldos.containsKey(id)) {
                // Produto sem linha de saldo (não deveria ocorrer): cria zerada dentro desta transação.
                saldos.put(id, estoqueRepository.saveAndFlush(new Estoque(id)));
            }
        }
        return saldos;
    }

    private static void validarSentido(Movimento m) {
        if (m.quantidade() == null || m.quantidade().signum() == 0) {
            throw new NegocioException("QUANTIDADE_INVALIDA", "A quantidade deve ser diferente de zero.");
        }
        boolean ok = switch (m.tipo().sentido()) {
            case ENTRADA -> m.quantidade().signum() > 0;
            case SAIDA -> m.quantidade().signum() < 0;
            case AJUSTE -> true;
        };
        if (!ok) {
            throw new IllegalArgumentException("Quantidade com sinal incompatível com " + m.tipo());
        }
    }

    private static String texto(BigDecimal valor) {
        return valor.stripTrailingZeros().toPlainString();
    }
}
