package br.com.bar.gestao;

import br.com.bar.gestao.estoque.api.dto.EstoqueDto;
import br.com.bar.gestao.estoque.application.EstoqueOperacoesService;
import br.com.bar.gestao.estoque.application.EstoqueService;
import br.com.bar.gestao.estoque.domain.TipoMovimentacao;
import br.com.bar.gestao.shared.exception.NegocioException;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 2 — movimentações, conversões, bloqueio de negativo, inventário e concorrência, com PostgreSQL real. */
class EstoqueIntegrationTest extends IntegracaoBase {

    @Autowired EstoqueOperacoesService operacoes;
    @Autowired EstoqueService estoqueService;

    private String caixa12() throws Exception {
        return "[{\"unidadeId\":\"%s\",\"descricao\":\"Caixa 12\",\"fator\":12}]".formatted(idUnidade("cx"));
    }

    @Test
    void entradaPerdaAjusteEHistorico() throws Exception {
        String id = criarProduto("Long neck " + UUID.randomUUID(), "un", "4.00", caixa12());
        String caixaId = JsonPath.read(corpo(getAuth("/api/admin/produtos/{id}", id)), "$.embalagens[0].id");

        // Entrada de 2 caixas = 24 unidades
        postJson("/api/admin/estoque/entradas",
                "{\"produtoId\":\"%s\",\"quantidade\":2,\"embalagemId\":\"%s\"}".formatted(id, caixaId))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.quantidade").value(24))
                .andExpect(jsonPath("$.saldoPosterior").value(24))
                .andExpect(jsonPath("$.quantidadeInformada").value("2 × Caixa 12"));

        // Perda exige motivo
        postJson("/api/admin/estoque/saidas", "{\"produtoId\":\"%s\",\"tipo\":\"PERDA\",\"quantidade\":5}".formatted(id))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("OBSERVACAO_OBRIGATORIA"));
        postJson("/api/admin/estoque/saidas",
                "{\"produtoId\":\"%s\",\"tipo\":\"PERDA\",\"quantidade\":5,\"observacao\":\"garrafas quebradas\"}".formatted(id))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.quantidade").value(-5))
                .andExpect(jsonPath("$.saldoPosterior").value(19));

        // Saída maior que o saldo é bloqueada (estoque negativo desativado por padrão)
        postJson("/api/admin/estoque/saidas",
                "{\"produtoId\":\"%s\",\"tipo\":\"CONSUMO_INTERNO\",\"quantidade\":100}".formatted(id))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("ESTOQUE_INSUFICIENTE"));

        // Tipo de saída reservado ao sistema não pode ser usado manualmente
        postJson("/api/admin/estoque/saidas",
                "{\"produtoId\":\"%s\",\"tipo\":\"SAIDA_VENDA\",\"quantidade\":1}".formatted(id))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("TIPO_INVALIDO"));

        // Ajuste avulso: contou 20 (sistema 19) → +1; repetir não gera nada
        postJson("/api/admin/estoque/ajustes",
                "{\"produtoId\":\"%s\",\"quantidadeContada\":20,\"observacao\":\"conferência\"}".formatted(id))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tipo").value("AJUSTE_INVENTARIO"))
                .andExpect(jsonPath("$.quantidade").value(1));
        postJson("/api/admin/estoque/ajustes",
                "{\"produtoId\":\"%s\",\"quantidadeContada\":20,\"observacao\":\"conferência\"}".formatted(id))
                .andExpect(status().isNoContent());

        getAuth("/api/admin/estoque/movimentacoes?produtoId={id}", id)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElementos").value(3))
                .andExpect(jsonPath("$.conteudo[0].tipo").value("AJUSTE_INVENTARIO"))
                .andExpect(jsonPath("$.conteudo[2].tipo").value("ENTRADA_MANUAL"));

        getAuth("/api/admin/produtos/{id}", id).andExpect(jsonPath("$.estoqueAtual").value(20));

        // Produto com movimentações não pode ser excluído nem trocar de unidade de estoque
        mvc.perform(delete("/api/admin/produtos/{id}", id).header("Authorization", token))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("PRODUTO_COM_MOVIMENTACOES"));
    }

    @Test
    void entradaEmQuilogramasEmProdutoControladoEmGramas() throws Exception {
        String id = criarProduto("Batata " + UUID.randomUUID(), "g", "0.02", "[]");
        postJson("/api/admin/estoque/entradas",
                "{\"produtoId\":\"%s\",\"quantidade\":2.5,\"unidadeId\":\"%s\"}".formatted(id, idUnidade("kg")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.quantidade").value(2500))
                .andExpect(jsonPath("$.quantidadeInformada").value("2.5 kg"));

        // Unidade de outra grandeza é rejeitada
        postJson("/api/admin/estoque/entradas",
                "{\"produtoId\":\"%s\",\"quantidade\":1,\"unidadeId\":\"%s\"}".formatted(id, idUnidade("L")))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("UNIDADES_INCOMPATIVEIS"));

        String nome = JsonPath.read(corpo(getAuth("/api/admin/produtos/{id}", id)), "$.nome");
        getAuth("/api/admin/estoque?nome={nome}", nome)
                .andExpect(jsonPath("$.conteudo[0].quantidade").value(2500))
                .andExpect(jsonPath("$.conteudo[0].valorEstoque").value(50.0));
    }

    @Test
    void inventarioCompleto() throws Exception {
        String categoriaId = JsonPath.read(corpo(postJson("/api/admin/categorias",
                "{\"nome\":\"Inventário %s\"}".formatted(UUID.randomUUID().toString().substring(0, 8)))), "$.id");
        String a = criarProdutoNaCategoria("Gin", categoriaId);
        String b = criarProdutoNaCategoria("Vodka", categoriaId);
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":10}".formatted(a)).andExpect(status().isCreated());
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":5}".formatted(b)).andExpect(status().isCreated());

        String inv = corpo(postJson("/api/admin/estoque/inventarios",
                "{\"descricao\":\"Contagem do bar\",\"categoriaId\":\"%s\"}".formatted(categoriaId))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.totalItens").value(2))
                .andExpect(jsonPath("$.status").value("ABERTO")));
        String invId = JsonPath.read(inv, "$.id");

        // Só um inventário aberto por vez
        postJson("/api/admin/estoque/inventarios", "{\"descricao\":\"Outro\"}")
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("INVENTARIO_EM_ANDAMENTO"));

        // Contou 8 de A (sistema 10) e deixou B sem contar
        mvc.perform(put("/api/admin/estoque/inventarios/{id}/contagens", invId).header("Authorization", token)
                        .contentType("application/json")
                        .content("{\"contagens\":[{\"produtoId\":\"%s\",\"quantidadeContada\":8}]}".formatted(a)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.itensContados").value(1))
                .andExpect(jsonPath("$.itensComDiferenca").value(1));

        // Uma venda/saída durante a contagem: A vai a 9. A diferença é calculada na conclusão.
        postJson("/api/admin/estoque/saidas",
                "{\"produtoId\":\"%s\",\"tipo\":\"CONSUMO_INTERNO\",\"quantidade\":1}".formatted(a)).andExpect(status().isCreated());

        postJson("/api/admin/estoque/inventarios/" + invId + "/concluir", "{}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CONCLUIDO"))
                .andExpect(jsonPath("$.itens[?(@.produtoId == '%s')].quantidadeSistema".formatted(a)).value(9.0))
                .andExpect(jsonPath("$.itens[?(@.produtoId == '%s')].diferenca".formatted(a)).value(-1.0));

        getAuth("/api/admin/produtos/{id}", a).andExpect(jsonPath("$.estoqueAtual").value(8));
        getAuth("/api/admin/produtos/{id}", b).andExpect(jsonPath("$.estoqueAtual").value(5)); // não contado: intacto

        // Inventário concluído não aceita alterações
        postJson("/api/admin/estoque/inventarios/" + invId + "/cancelar", "{}")
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.codigo").value("INVENTARIO_ENCERRADO"));
    }

    @Test
    void saidasSimultaneasNuncaDeixamOEstoqueNegativo() throws Exception {
        String id = criarProduto("Concorrência " + UUID.randomUUID(), "un", "1", "[]");
        postJson("/api/admin/estoque/entradas", "{\"produtoId\":\"%s\",\"quantidade\":10}".formatted(id)).andExpect(status().isCreated());

        // 8 operações simultâneas tentando retirar 3 unidades cada (total 24) de um saldo de 10.
        int threads = 8;
        CountDownLatch largada = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        List<Future<Boolean>> resultados = new ArrayList<>();
        Callable<Boolean> saida = () -> {
            largada.await();
            try {
                operacoes.registrarSaida(new EstoqueDto.SaidaRequest(UUID.fromString(id),
                        TipoMovimentacao.CONSUMO_INTERNO, new BigDecimal("3"), null, null, "teste"));
                return true;
            } catch (NegocioException e) {
                assertThat(e.getCodigo()).isEqualTo("ESTOQUE_INSUFICIENTE");
                return false;
            }
        };
        for (int i = 0; i < threads; i++) resultados.add(pool.submit(saida));
        largada.countDown();
        int sucessos = 0;
        for (Future<Boolean> f : resultados) if (f.get()) sucessos++;
        pool.shutdown();

        assertThat(sucessos).isEqualTo(3);                                            // 3 × 3 = 9 ≤ 10
        assertThat(estoqueService.quantidade(UUID.fromString(id))).isEqualByComparingTo("1");
        getAuth("/api/admin/estoque/movimentacoes?produtoId={id}", id)
                .andExpect(jsonPath("$.totalElementos").value(4))                    // 1 entrada + 3 saídas
                .andExpect(jsonPath("$.conteudo[0].saldoPosterior").value(1));
    }

    private String criarProdutoNaCategoria(String nome, String categoriaId) throws Exception {
        String json = """
                {"nome":"%s %s","tipo":"REVENDA","categoriaId":"%s","unidadeEstoqueId":"%s","custoMedio":2,
                 "precoVenda":10,"estoqueMinimo":0}
                """.formatted(nome, UUID.randomUUID(), categoriaId, idUnidade("un"));
        return JsonPath.read(corpo(postJson("/api/admin/produtos", json).andExpect(status().isCreated())), "$.id");
    }
}
