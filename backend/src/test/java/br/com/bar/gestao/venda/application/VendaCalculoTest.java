package br.com.bar.gestao.venda.application;

import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.venda.domain.FormaPagamento;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class VendaCalculoTest {

    private static BigDecimal bd(String v) {
        return new BigDecimal(v);
    }

    @Test
    void valorDoItemArredondaParaCentavos() {
        assertThat(VendaCalculo.valor(bd("7.90"), bd("3"))).isEqualByComparingTo("23.70");
        assertThat(VendaCalculo.valor(bd("10.00"), bd("0.333"))).isEqualByComparingTo("3.33");
    }

    @Test
    void descontoEmValorOuPercentual() {
        assertThat(VendaCalculo.desconto(bd("46"), bd("6"), null)).isEqualByComparingTo("6.00");
        assertThat(VendaCalculo.desconto(bd("8"), null, bd("10"))).isEqualByComparingTo("0.80");
        assertThat(VendaCalculo.desconto(bd("8"), null, null)).isEqualByComparingTo("0");
        assertThat(VendaCalculo.desconto(bd("8"), BigDecimal.ZERO, BigDecimal.ZERO)).isEqualByComparingTo("0");
    }

    @Test
    void descontoNaoPodeSuperarOSubtotalNemSerDuplo() {
        assertThatThrownBy(() -> VendaCalculo.desconto(bd("10"), bd("11"), null))
                .isInstanceOf(NegocioException.class).extracting("codigo").isEqualTo("DESCONTO_INVALIDO");
        assertThatThrownBy(() -> VendaCalculo.desconto(bd("10"), bd("1"), bd("5")))
                .isInstanceOf(NegocioException.class).extracting("codigo").isEqualTo("DESCONTO_INVALIDO");
    }

    @Test
    void trocoSoNoDinheiro() {
        var dinheiro = VendaCalculo.recebimento(FormaPagamento.DINHEIRO, bd("40.00"), bd("50"));
        assertThat(dinheiro.valorRecebido()).isEqualByComparingTo("50");
        assertThat(dinheiro.troco()).isEqualByComparingTo("10");

        var exato = VendaCalculo.recebimento(FormaPagamento.DINHEIRO, bd("40.00"), null);
        assertThat(exato.troco()).isEqualByComparingTo("0");

        var pix = VendaCalculo.recebimento(FormaPagamento.PIX, bd("40.00"), bd("50"));
        assertThat(pix.valorRecebido()).isNull();
        assertThat(pix.troco()).isNull();
    }

    @Test
    void valorRecebidoMenorQueOTotalEhRecusado() {
        assertThatThrownBy(() -> VendaCalculo.recebimento(FormaPagamento.DINHEIRO, bd("40"), bd("30")))
                .isInstanceOf(NegocioException.class).extracting("codigo").isEqualTo("VALOR_RECEBIDO_INSUFICIENTE");
    }
}
