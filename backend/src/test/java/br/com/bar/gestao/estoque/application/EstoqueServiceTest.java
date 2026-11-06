package br.com.bar.gestao.estoque.application;

import br.com.bar.gestao.configuracao.application.ConfiguracaoService;
import br.com.bar.gestao.estoque.domain.Estoque;
import br.com.bar.gestao.estoque.domain.EstoqueRepository;
import br.com.bar.gestao.estoque.domain.MovimentacaoEstoque;
import br.com.bar.gestao.estoque.domain.MovimentacaoEstoqueRepository;
import br.com.bar.gestao.estoque.domain.OrigemMovimentacao;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EstoqueServiceTest {

    @Mock EstoqueRepository estoqueRepository;
    @Mock MovimentacaoEstoqueRepository movimentacaoRepository;
    @Mock ConfiguracaoService configuracao;
    @InjectMocks EstoqueService service;

    private final UUID produtoId = UUID.randomUUID();
    private Estoque saldo;

    @BeforeEach
    void setUp() {
        saldo = new Estoque(produtoId);
        saldo.aplicar(new BigDecimal("10"));
        when(estoqueRepository.travar(anyCollection())).thenReturn(List.of(saldo));
        when(movimentacaoRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        when(configuracao.ativo(ConfiguracaoService.PERMITIR_ESTOQUE_NEGATIVO)).thenReturn(false);
    }

    private EstoqueService.Movimento movimento(TipoMovimentacao tipo, String quantidade) {
        return new EstoqueService.Movimento(produtoId, "Cerveja", "un", tipo, new BigDecimal(quantidade),
                new BigDecimal("3.50"), null, OrigemMovimentacao.MANUAL, null, null);
    }

    @Test
    void entradaSomaAoSaldoERegistraAnteriorEPosterior() {
        MovimentacaoEstoque mov = service.movimentar(movimento(TipoMovimentacao.ENTRADA_MANUAL, "24"));

        assertThat(saldo.getQuantidade()).isEqualByComparingTo("34");
        assertThat(mov.getSaldoAnterior()).isEqualByComparingTo("10");
        assertThat(mov.getSaldoPosterior()).isEqualByComparingTo("34");
        assertThat(mov.getCustoUnitario()).isEqualByComparingTo("3.50");
    }

    @Test
    void saidaSubtraiDoSaldo() {
        service.movimentar(movimento(TipoMovimentacao.PERDA, "-4"));
        assertThat(saldo.getQuantidade()).isEqualByComparingTo("6");
    }

    @Test
    void bloqueiaSaidaMaiorQueOSaldo() {
        assertThatThrownBy(() -> service.movimentar(movimento(TipoMovimentacao.CONSUMO_INTERNO, "-11")))
                .isInstanceOf(NegocioException.class)
                .hasMessageContaining("disponível 10 un")
                .extracting("codigo").isEqualTo("ESTOQUE_INSUFICIENTE");
        assertThat(saldo.getQuantidade()).isEqualByComparingTo("10");
        verify(movimentacaoRepository, never()).save(any());
    }

    @Test
    void permiteNegativoQuandoConfigurado() {
        when(configuracao.ativo(ConfiguracaoService.PERMITIR_ESTOQUE_NEGATIVO)).thenReturn(true);
        service.movimentar(movimento(TipoMovimentacao.CONSUMO_INTERNO, "-11"));
        assertThat(saldo.getQuantidade()).isEqualByComparingTo("-1");
    }

    @Test
    void quantidadeReservadaNaoPodeSerConsumida() {
        ReflectionTestUtils.setField(saldo, "quantidadeReservada", new BigDecimal("8"));
        assertThatThrownBy(() -> service.movimentar(movimento(TipoMovimentacao.PERDA, "-3")))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("ESTOQUE_INSUFICIENTE");
    }

    @Test
    void validaSaldoAcumuladoEmVariasSaidasDoMesmoProduto() {
        // Ex.: dois itens da mesma venda consumindo o mesmo ingrediente.
        assertThatThrownBy(() -> service.movimentar(List.of(
                movimento(TipoMovimentacao.CONSUMO_RECEITA, "-6"),
                movimento(TipoMovimentacao.CONSUMO_RECEITA, "-6"))))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("ESTOQUE_INSUFICIENTE");
    }

    @Test
    void rejeitaSinalIncompativelComOTipo() {
        assertThatThrownBy(() -> service.movimentar(movimento(TipoMovimentacao.ENTRADA_MANUAL, "-1")))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.movimentar(movimento(TipoMovimentacao.PERDA, "1")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void ajusteGeraMovimentacaoComADiferenca() {
        var resultado = service.ajustarPara(List.of(new EstoqueService.AjusteAlvo(produtoId, new BigDecimal("7"),
                BigDecimal.ONE, OrigemMovimentacao.INVENTARIO, null, "Inventário"))).getFirst();

        assertThat(resultado.saldoAnterior()).isEqualByComparingTo("10");
        assertThat(resultado.diferenca()).isEqualByComparingTo("-3");
        assertThat(resultado.movimentacao().getTipo()).isEqualTo(TipoMovimentacao.AJUSTE_INVENTARIO);
        assertThat(saldo.getQuantidade()).isEqualByComparingTo("7");
    }

    @Test
    void ajusteSemDiferencaNaoGeraMovimentacao() {
        var resultado = service.ajustarPara(List.of(new EstoqueService.AjusteAlvo(produtoId, new BigDecimal("10"),
                BigDecimal.ONE, OrigemMovimentacao.AJUSTE_AVULSO, null, "Conferência"))).getFirst();

        assertThat(resultado.movimentacao()).isNull();
        verify(movimentacaoRepository, never()).save(any());
    }
}
