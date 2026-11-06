package br.com.bar.gestao.caixa.application;

import br.com.bar.gestao.caixa.api.dto.CaixaDto;
import br.com.bar.gestao.caixa.domain.Caixa;
import br.com.bar.gestao.caixa.domain.CaixaRepository;
import br.com.bar.gestao.caixa.domain.MovimentacaoCaixa;
import br.com.bar.gestao.caixa.domain.MovimentacaoCaixaRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Controle de caixa: abertura, suprimentos/retiradas e fechamento com conferência.
 *
 * <p>Concorrência: vendas travam o caixa em modo compartilhado e o fechamento em modo exclusivo,
 * então nenhuma venda entra num caixa depois que os totais do fechamento foram apurados.
 */
@Service
public class CaixaService {

    private static final Logger log = LoggerFactory.getLogger(CaixaService.class);

    private final CaixaRepository repository;
    private final MovimentacaoCaixaRepository movimentacoes;
    private final JdbcClient jdbc;

    public CaixaService(CaixaRepository repository, MovimentacaoCaixaRepository movimentacoes, JdbcClient jdbc) {
        this.repository = repository;
        this.movimentacoes = movimentacoes;
        this.jdbc = jdbc;
    }

    // ---------------------------------------------------------------- uso pelas vendas

    /** Id do caixa aberto, travado em modo compartilhado até o fim da transação da venda. */
    @Transactional(propagation = Propagation.MANDATORY)
    public UUID travarCaixaAberto() {
        return repository.travarCompartilhadoPorStatus(Caixa.Status.ABERTO)
                .orElseThrow(() -> new NegocioException("CAIXA_FECHADO", "Abra o caixa antes de registrar vendas."))
                .getId();
    }

    /** Exige que o caixa informado continue aberto (ex.: para cancelar uma venda dele). */
    @Transactional(propagation = Propagation.MANDATORY)
    public void exigirAberto(UUID caixaId, String mensagem) {
        Caixa caixa = repository.travarCompartilhado(caixaId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Caixa", caixaId));
        if (!caixa.isAberto()) {
            throw new NegocioException("CAIXA_FECHADO", mensagem);
        }
    }

    // ---------------------------------------------------------------- operações

    @Transactional
    public CaixaDto.Response abrir(CaixaDto.AbrirRequest req) {
        if (repository.findByStatus(Caixa.Status.ABERTO).isPresent()) {
            throw new NegocioException("CAIXA_JA_ABERTO", "Já existe um caixa aberto.");
        }
        Caixa caixa = repository.saveAndFlush(new Caixa(req.saldoInicial(), texto(req.observacao())));
        log.info("Caixa aberto: id={} saldoInicial={}", caixa.getId(), caixa.getSaldoInicial());
        return resposta(caixa);
    }

    @Transactional
    public CaixaDto.Response movimentar(CaixaDto.MovimentoRequest req) {
        Caixa caixa = caixaAbertoExclusivo();
        if (req.tipo() == MovimentacaoCaixa.Tipo.RETIRADA) {
            BigDecimal disponivel = totais(caixa).saldoEsperado();
            if (req.valor().compareTo(disponivel) > 0) {
                throw new NegocioException("SALDO_INSUFICIENTE", "A retirada (" + req.valor()
                        + ") é maior que o dinheiro esperado na gaveta (" + disponivel + ").");
            }
        }
        movimentacoes.save(new MovimentacaoCaixa(caixa.getId(), req.tipo(), req.valor(), req.motivo().trim()));
        log.info("Caixa {}: {} de {} ({})", caixa.getId(), req.tipo(), req.valor(), req.motivo());
        return resposta(caixa);
    }

    @Transactional
    public CaixaDto.Response fechar(CaixaDto.FecharRequest req) {
        Caixa caixa = caixaAbertoExclusivo();
        Caixa.Totais totais = totais(caixa);
        caixa.fechar(totais, req.saldoContado(), texto(req.observacao()));
        log.info("Caixa fechado: id={} vendas={} esperado={} contado={} diferença={}", caixa.getId(),
                totais.totalVendas(), totais.saldoEsperado(), req.saldoContado(), caixa.getDiferenca());
        return resposta(caixa);
    }

    // ---------------------------------------------------------------- consultas

    @Transactional(readOnly = true)
    public Optional<CaixaDto.Response> atual() {
        return repository.findByStatus(Caixa.Status.ABERTO).map(this::resposta);
    }

    @Transactional(readOnly = true)
    public CaixaDto.Response buscar(UUID id) {
        return resposta(repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Caixa", id)));
    }

    @Transactional(readOnly = true)
    public Page<CaixaDto.Response> historico(Pageable pageable) {
        return repository.findAll(pageable).map(c -> resposta(c, false));
    }

    // ---------------------------------------------------------------- interno

    private Caixa caixaAbertoExclusivo() {
        Caixa aberto = repository.findByStatus(Caixa.Status.ABERTO)
                .orElseThrow(() -> new NegocioException("CAIXA_FECHADO", "Não há caixa aberto."));
        Caixa caixa = repository.travarExclusivo(aberto.getId()).orElseThrow();
        caixa.exigirAberto();
        return caixa;
    }

    private record Apuracao(Caixa.Totais totais, BigDecimal lucroBruto, int canceladas) {
    }

    private Caixa.Totais totais(Caixa caixa) {
        return apurar(caixa).totais();
    }

    /** Soma as vendas concluídas por forma de pagamento e as movimentações de dinheiro do caixa. */
    private Apuracao apurar(Caixa caixa) {
        return jdbc.sql("""
                        SELECT
                          (SELECT count(*) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA') AS qtd,
                          (SELECT count(*) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CANCELADA') AS canceladas,
                          coalesce((SELECT sum(total) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA'), 0) AS total,
                          coalesce((SELECT sum(lucro_bruto) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA'), 0) AS lucro,
                          coalesce((SELECT sum(total) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA' AND v.forma_pagamento = 'DINHEIRO'), 0) AS dinheiro,
                          coalesce((SELECT sum(total) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA' AND v.forma_pagamento = 'PIX'), 0) AS pix,
                          coalesce((SELECT sum(total) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA' AND v.forma_pagamento = 'CARTAO_DEBITO'), 0) AS debito,
                          coalesce((SELECT sum(total) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA' AND v.forma_pagamento = 'CARTAO_CREDITO'), 0) AS credito,
                          coalesce((SELECT sum(total) FROM venda v WHERE v.caixa_id = :id AND v.status = 'CONCLUIDA' AND v.forma_pagamento = 'OUTROS'), 0) AS outros,
                          coalesce((SELECT sum(valor) FROM movimentacao_caixa m WHERE m.caixa_id = :id AND m.tipo = 'SUPRIMENTO'), 0) AS suprimentos,
                          coalesce((SELECT sum(valor) FROM movimentacao_caixa m WHERE m.caixa_id = :id AND m.tipo = 'RETIRADA'), 0) AS retiradas
                        """)
                .param("id", caixa.getId())
                .query((rs, n) -> {
                    BigDecimal dinheiro = rs.getBigDecimal("dinheiro");
                    BigDecimal suprimentos = rs.getBigDecimal("suprimentos");
                    BigDecimal retiradas = rs.getBigDecimal("retiradas");
                    BigDecimal esperado = caixa.getSaldoInicial().add(dinheiro).add(suprimentos).subtract(retiradas);
                    return new Apuracao(new Caixa.Totais(rs.getInt("qtd"), rs.getBigDecimal("total"), dinheiro,
                            rs.getBigDecimal("pix"), rs.getBigDecimal("debito"), rs.getBigDecimal("credito"),
                            rs.getBigDecimal("outros"), suprimentos, retiradas, esperado),
                            rs.getBigDecimal("lucro"), rs.getInt("canceladas"));
                })
                .single();
    }

    private CaixaDto.Response resposta(Caixa caixa) {
        return resposta(caixa, true);
    }

    private CaixaDto.Response resposta(Caixa caixa, boolean comMovimentacoes) {
        Apuracao apuracao = apurar(caixa);
        Caixa.Totais totais = caixa.isAberto() ? apuracao.totais() : caixa.totaisCongelados();
        return new CaixaDto.Response(caixa.getId(), caixa.getStatus(), caixa.getAbertoEm(), caixa.getFechadoEm(),
                caixa.getSaldoInicial(), totais, apuracao.lucroBruto(), apuracao.canceladas(), caixa.getSaldoContado(),
                caixa.getDiferenca(), caixa.getObservacaoAbertura(), caixa.getObservacaoFechamento(),
                comMovimentacoes
                        ? movimentacoes.findByCaixaIdOrderByDataHora(caixa.getId()).stream()
                        .map(CaixaDto.MovimentoResponse::of).toList()
                        : java.util.List.of());
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
