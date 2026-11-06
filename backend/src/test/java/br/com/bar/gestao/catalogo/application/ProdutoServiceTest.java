package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.api.dto.ProdutoDto;
import br.com.bar.gestao.catalogo.domain.CategoriaRepository;
import br.com.bar.gestao.catalogo.domain.Grandeza;
import br.com.bar.gestao.catalogo.domain.ProdutoRepository;
import br.com.bar.gestao.catalogo.domain.TipoProduto;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import br.com.bar.gestao.catalogo.domain.UnidadeMedidaRepository;
import br.com.bar.gestao.estoque.application.EstoqueService;
import br.com.bar.gestao.fornecedor.application.FornecedorService;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.storage.ImagemStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ProdutoServiceTest {

    @Mock ProdutoRepository produtoRepository;
    @Mock CategoriaRepository categoriaRepository;
    @Mock UnidadeMedidaRepository unidadeRepository;
    @Mock FornecedorService fornecedorService;
    @Mock EstoqueService estoqueService;
    @Mock ImagemStorageService imagemStorage;
    @InjectMocks ProdutoService service;

    private final UnidadeMedida un = new UnidadeMedida("un", "Unidade", Grandeza.UNIDADE, BigDecimal.ONE);
    private final UnidadeMedida kg = new UnidadeMedida("kg", "Quilograma", Grandeza.MASSA, new BigDecimal("1000"));
    private final UnidadeMedida caixa = new UnidadeMedida("cx", "Caixa", Grandeza.EMBALAGEM, null);

    @BeforeEach
    void setUp() {
        when(unidadeRepository.findById(un.getId())).thenReturn(Optional.of(un));
        when(unidadeRepository.findById(kg.getId())).thenReturn(Optional.of(kg));
        when(unidadeRepository.findById(caixa.getId())).thenReturn(Optional.of(caixa));
        when(produtoRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        when(estoqueService.quantidade(any())).thenReturn(BigDecimal.ZERO);
    }

    private ProdutoDto.Request request(TipoProduto tipo, UnidadeMedida unidade, BigDecimal preco, boolean cardapio,
                                       List<ProdutoDto.EmbalagemRequest> embalagens) {
        return new ProdutoDto.Request("Cerveja lata", null, null, tipo, unidade.getId(), new BigDecimal("3.50"), preco,
                new BigDecimal("48"), null, null, cardapio, embalagens, null, null, null, null);
    }

    @Test
    void criaProdutoDeRevendaComEmbalagemEInicializaEstoque() {
        var caixa12 = new ProdutoDto.EmbalagemRequest(null, caixa.getId(), "Caixa 12", new BigDecimal("12"));

        ProdutoDto.Response r = service.criar(request(TipoProduto.REVENDA, un, new BigDecimal("8.00"), true, List.of(caixa12)));

        assertThat(r.precoVenda()).isEqualByComparingTo("8.00");
        assertThat(r.margemBrutaPercentual()).isEqualByComparingTo("56.25");
        assertThat(r.embalagens()).singleElement().satisfies(e -> assertThat(e.fator()).isEqualByComparingTo("12"));
        assertThat(r.abaixoMinimo()).isTrue();
        verify(estoqueService).inicializar(r.id());
    }

    @Test
    void exigeUnidadeBaseComoUnidadeDeEstoque() {
        assertThatThrownBy(() -> service.criar(request(TipoProduto.INGREDIENTE, kg, null, false, List.of())))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("UNIDADE_ESTOQUE_INVALIDA");
        verify(produtoRepository, never()).save(any());
    }

    @Test
    void exigePrecoParaProdutoVendavel() {
        assertThatThrownBy(() -> service.criar(request(TipoProduto.REVENDA, un, null, false, List.of())))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("PRECO_VENDA_OBRIGATORIO");
    }

    @Test
    void ingredienteNaoTemPrecoNemApareceNoCardapio() {
        ProdutoDto.Response r = service.criar(request(TipoProduto.INGREDIENTE, un, new BigDecimal("5"), true, List.of()));

        assertThat(r.precoVenda()).isNull();
        assertThat(r.vendeNoCardapio()).isFalse();
        assertThat(r.margemBrutaPercentual()).isNull();
    }

    @Test
    void embalagemPrecisaUsarUnidadeDoTipoEmbalagem() {
        var errada = new ProdutoDto.EmbalagemRequest(null, kg.getId(), "Quilo", new BigDecimal("1000"));
        assertThatThrownBy(() -> service.criar(request(TipoProduto.REVENDA, un, BigDecimal.TEN, false, List.of(errada))))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("EMBALAGEM_INVALIDA");
    }

    @Test
    void rejeitaEmbalagensRepetidas() {
        var a = new ProdutoDto.EmbalagemRequest(null, caixa.getId(), "Caixa 12", new BigDecimal("12"));
        var b = new ProdutoDto.EmbalagemRequest(null, caixa.getId(), "caixa 12", new BigDecimal("12"));
        assertThatThrownBy(() -> service.criar(request(TipoProduto.REVENDA, un, BigDecimal.TEN, false, List.of(a, b))))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("EMBALAGEM_DUPLICADA");
    }

    @Test
    void rejeitaCodigoInternoDuplicado() {
        when(produtoRepository.existsByCodigoInternoIgnoreCaseAndIdNot(any(), any())).thenReturn(true);
        var req = new ProdutoDto.Request("Cerveja", null, null, TipoProduto.REVENDA, un.getId(), BigDecimal.ONE,
                BigDecimal.TEN, BigDecimal.ZERO, null, "CRV01", false, List.of(), null, null, null, null);

        assertThatThrownBy(() -> service.criar(req))
                .isInstanceOf(NegocioException.class)
                .extracting("codigo").isEqualTo("CODIGO_INTERNO_DUPLICADO");
    }
}
