package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.domain.Grandeza;
import br.com.bar.gestao.catalogo.domain.Produto;
import br.com.bar.gestao.catalogo.domain.TipoProduto;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ConversaoUnidadeServiceTest {

    private final ConversaoUnidadeService conversao = new ConversaoUnidadeService();

    private final UnidadeMedida un = new UnidadeMedida("un", "Unidade", Grandeza.UNIDADE, BigDecimal.ONE);
    private final UnidadeMedida g = new UnidadeMedida("g", "Grama", Grandeza.MASSA, BigDecimal.ONE);
    private final UnidadeMedida kg = new UnidadeMedida("kg", "Quilograma", Grandeza.MASSA, new BigDecimal("1000"));
    private final UnidadeMedida ml = new UnidadeMedida("ml", "Mililitro", Grandeza.VOLUME, BigDecimal.ONE);
    private final UnidadeMedida litro = new UnidadeMedida("L", "Litro", Grandeza.VOLUME, new BigDecimal("1000"));
    private final UnidadeMedida caixa = new UnidadeMedida("cx", "Caixa", Grandeza.EMBALAGEM, null);
    private final UnidadeMedida pacote = new UnidadeMedida("pct", "Pacote", Grandeza.EMBALAGEM, null);

    @Test
    void converteQuilogramaParaGrama() {
        assertThat(conversao.converter(new BigDecimal("2"), kg, g)).isEqualByComparingTo("2000");
    }

    @Test
    void converteGramaParaQuilograma() {
        assertThat(conversao.converter(new BigDecimal("300"), g, kg)).isEqualByComparingTo("0.3");
    }

    @Test
    void converteLitroParaMililitro() {
        assertThat(conversao.converter(new BigDecimal("1.5"), litro, ml)).isEqualByComparingTo("1500");
    }

    @Test
    void mesmaUnidadeRetornaMesmaQuantidade() {
        assertThat(conversao.converter(new BigDecimal("7"), un, un)).isEqualByComparingTo("7");
    }

    @Test
    void rejeitaGrandezasIncompativeis() {
        assertThatThrownBy(() -> conversao.converter(BigDecimal.ONE, kg, ml))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("UNIDADES_INCOMPATIVEIS");
    }

    @Test
    void rejeitaEmbalagemSemProduto() {
        assertThatThrownBy(() -> conversao.converter(BigDecimal.ONE, caixa, un))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("CONVERSAO_INVALIDA");
    }

    @Test
    void caixaDe12CervejasViraDozeUnidadesNoEstoque() {
        Produto cerveja = new Produto("Cerveja lata", TipoProduto.REVENDA, un);
        cerveja.sincronizarEmbalagens(List.of(new Produto.DadosEmbalagem(null, caixa, "Caixa 12", new BigDecimal("12"))));
        UUID caixaId = cerveja.getEmbalagens().getFirst().getId();

        assertThat(conversao.paraUnidadeEstoque(cerveja, BigDecimal.ONE, null, caixaId)).isEqualByComparingTo("12");
        assertThat(conversao.paraUnidadeEstoque(cerveja, new BigDecimal("3"), null, caixaId)).isEqualByComparingTo("36");
    }

    @Test
    void pacoteDeBatataDe2kgViraDoisMilGramas() {
        Produto batata = new Produto("Batata congelada", TipoProduto.INGREDIENTE, g);
        batata.sincronizarEmbalagens(List.of(new Produto.DadosEmbalagem(null, pacote, "Pacote 2 kg", new BigDecimal("2000"))));
        UUID pacoteId = batata.getEmbalagens().getFirst().getId();

        assertThat(conversao.paraUnidadeEstoque(batata, BigDecimal.ONE, null, pacoteId)).isEqualByComparingTo("2000");
    }

    @Test
    void compraEmQuilogramaConverteParaUnidadeDeEstoqueEmGramas() {
        Produto batata = new Produto("Batata congelada", TipoProduto.INGREDIENTE, g);
        assertThat(conversao.paraUnidadeEstoque(batata, new BigDecimal("2"), kg, null)).isEqualByComparingTo("2000");
    }

    @Test
    void rejeitaEmbalagemDeOutroProduto() {
        Produto batata = new Produto("Batata congelada", TipoProduto.INGREDIENTE, g);
        assertThatThrownBy(() -> conversao.paraUnidadeEstoque(batata, BigDecimal.ONE, null, UUID.randomUUID()))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("EMBALAGEM_INVALIDA");
    }
}
