package br.com.bar.gestao.catalogo.application;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static br.com.bar.gestao.catalogo.application.CustoProdutoService.custoMedioPonderado;
import static org.assertj.core.api.Assertions.assertThat;

class CustoProdutoServiceTest {

    private static BigDecimal bd(String v) {
        return new BigDecimal(v);
    }

    @Test
    void mediaPonderadaEntreEstoqueAtualECompra() {
        // 12 latas a R$ 3,00 + 24 latas compradas a R$ 3,60 → (36 + 86,40) / 36 = R$ 3,40
        assertThat(custoMedioPonderado(bd("12"), bd("3.00"), bd("24"), bd("3.60"))).isEqualByComparingTo("3.40");
    }

    @Test
    void semEstoqueOCustoPassaASerODaCompra() {
        assertThat(custoMedioPonderado(BigDecimal.ZERO, bd("3.00"), bd("24"), bd("3.60"))).isEqualByComparingTo("3.60");
        assertThat(custoMedioPonderado(bd("-2"), bd("3.00"), bd("24"), bd("3.60"))).isEqualByComparingTo("3.60");
    }

    @Test
    void mantemPrecisaoParaCustosPorGrama() {
        // 500 g a R$ 0,02/g + 2000 g a R$ 0,025/g → (10 + 50) / 2500 = R$ 0,024/g
        assertThat(custoMedioPonderado(bd("500"), bd("0.02"), bd("2000"), bd("0.025"))).isEqualByComparingTo("0.024");
    }
}
