package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.api.dto.ProdutoDto;
import br.com.bar.gestao.catalogo.domain.Categoria;
import br.com.bar.gestao.catalogo.domain.CategoriaRepository;
import br.com.bar.gestao.catalogo.domain.Produto;
import br.com.bar.gestao.catalogo.domain.ProdutoRepository;
import br.com.bar.gestao.catalogo.domain.TipoProduto;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import br.com.bar.gestao.catalogo.domain.UnidadeMedidaRepository;
import br.com.bar.gestao.estoque.application.EstoqueService;
import br.com.bar.gestao.fornecedor.application.FornecedorService;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import br.com.bar.gestao.shared.storage.ImagemStorageService;
import jakarta.persistence.criteria.Predicate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Regras do cadastro de produtos. Retorna DTOs já montados (dentro da transação),
 * pois as relações do produto são carregadas sob demanda.
 */
@Service
public class ProdutoService {

    private static final Logger log = LoggerFactory.getLogger(ProdutoService.class);

    private final ProdutoRepository produtoRepository;
    private final CategoriaRepository categoriaRepository;
    private final UnidadeMedidaRepository unidadeRepository;
    private final FornecedorService fornecedorService;
    private final EstoqueService estoqueService;
    private final ImagemStorageService imagemStorage;

    public ProdutoService(ProdutoRepository produtoRepository, CategoriaRepository categoriaRepository,
                          UnidadeMedidaRepository unidadeRepository, FornecedorService fornecedorService,
                          EstoqueService estoqueService, ImagemStorageService imagemStorage) {
        this.produtoRepository = produtoRepository;
        this.categoriaRepository = categoriaRepository;
        this.unidadeRepository = unidadeRepository;
        this.fornecedorService = fornecedorService;
        this.estoqueService = estoqueService;
        this.imagemStorage = imagemStorage;
    }

    public record Filtro(String nome, UUID categoriaId, TipoProduto tipo, Boolean ativo) {
    }

    @Transactional(readOnly = true)
    public Page<ProdutoDto.Response> pesquisar(Filtro filtro, Pageable pageable) {
        Specification<Produto> spec = (root, query, cb) -> {
            List<Predicate> p = new ArrayList<>();
            if (filtro.nome() != null && !filtro.nome().isBlank()) {
                String termo = "%" + filtro.nome().trim().toLowerCase() + "%";
                p.add(cb.or(cb.like(cb.lower(root.get("nome")), termo),
                        cb.like(cb.lower(root.get("codigoInterno")), termo)));
            }
            if (filtro.categoriaId() != null) {
                p.add(cb.equal(root.get("categoria").get("id"), filtro.categoriaId()));
            }
            if (filtro.tipo() != null) {
                p.add(cb.equal(root.get("tipo"), filtro.tipo()));
            }
            if (filtro.ativo() != null) {
                p.add(cb.equal(root.get("ativo"), filtro.ativo()));
            }
            return cb.and(p.toArray(Predicate[]::new));
        };
        Page<Produto> pagina = produtoRepository.findAll(spec, pageable);
        Map<UUID, BigDecimal> estoques = estoqueService.quantidades(pagina.map(Produto::getId).getContent());
        return pagina.map(prod -> ProdutoDto.Response.of(prod, estoques.get(prod.getId())));
    }

    @Transactional(readOnly = true)
    public ProdutoDto.Response buscar(UUID id) {
        return resposta(carregar(id));
    }

    /** Busca pelo código exato (código de barras, QR Code ou código interno), ignorando maiúsculas. */
    @Transactional(readOnly = true)
    public ProdutoDto.Response buscarPorCodigo(String codigo) {
        String termo = codigo == null ? "" : codigo.trim();
        return produtoRepository.findByCodigoInternoIgnoreCase(termo)
                .map(this::resposta)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Produto com o código", termo));
    }

    @Transactional
    public ProdutoDto.Response criar(ProdutoDto.Request req) {
        UnidadeMedida unidade = unidadeEstoque(req.unidadeEstoqueId());
        Produto produto = new Produto(req.nome().trim(), req.tipo(), unidade);
        aplicar(produto, req, unidade, true);
        produtoRepository.save(produto);
        estoqueService.inicializar(produto.getId());
        log.info("Produto criado: id={} nome={} tipo={}", produto.getId(), produto.getNome(), produto.getTipo());
        return resposta(produto);
    }

    @Transactional
    public ProdutoDto.Response atualizar(UUID id, ProdutoDto.Request req) {
        Produto produto = carregar(id);
        UnidadeMedida unidade = unidadeEstoque(req.unidadeEstoqueId());
        // O histórico de movimentações está na unidade atual; trocá-la mudaria o sentido dos registros.
        if (!unidade.getId().equals(produto.getUnidadeEstoque().getId())
                && (estoqueService.quantidade(id).signum() != 0 || estoqueService.possuiMovimentacoes(id))) {
            throw new NegocioException("UNIDADE_ESTOQUE_BLOQUEADA",
                    "Não é possível alterar a unidade de estoque de um produto que já tem saldo ou movimentações.");
        }
        aplicar(produto, req, unidade, false);
        log.info("Produto atualizado: id={} nome={}", id, produto.getNome());
        return resposta(produto);
    }

    @Transactional
    public ProdutoDto.Response alterarStatus(UUID id, boolean ativo) {
        Produto produto = carregar(id);
        produto.alterarStatus(ativo);
        log.info("Produto {}: id={}", ativo ? "ativado" : "inativado", id);
        return resposta(produto);
    }

    /**
     * Exclusão física só é permitida para produtos sem histórico. As tabelas de movimentação,
     * vendas, receitas e compras referenciam o produto com FK restritiva, então qualquer
     * vínculo impede a exclusão — nesse caso o produto deve ser inativado.
     */
    @Transactional
    public void excluir(UUID id) {
        Produto produto = carregar(id);
        String imagem = produto.getImagemUrl();
        try {
            produtoRepository.delete(produto);
            produtoRepository.flush();
        } catch (DataIntegrityViolationException e) {
            throw new NegocioException("PRODUTO_COM_MOVIMENTACOES",
                    "O produto possui movimentações ou vínculos e não pode ser excluído. Inative-o.");
        }
        imagemStorage.removerPorUrl(imagem);
        log.info("Produto excluído: id={} nome={}", id, produto.getNome());
    }

    @Transactional
    public ProdutoDto.Response definirImagem(UUID id, MultipartFile arquivo) {
        Produto produto = carregar(id);
        String anterior = produto.getImagemUrl();
        produto.definirImagem(imagemStorage.salvar(arquivo));
        imagemStorage.removerPorUrl(anterior);
        log.info("Imagem do produto alterada: id={}", id);
        return resposta(produto);
    }

    @Transactional
    public ProdutoDto.Response removerImagem(UUID id) {
        Produto produto = carregar(id);
        imagemStorage.removerPorUrl(produto.getImagemUrl());
        produto.definirImagem(null);
        return resposta(produto);
    }

    // ------------------------------------------------------------------ regras

    private void aplicar(Produto produto, ProdutoDto.Request req, UnidadeMedida unidade, boolean novo) {
        Categoria categoria = categoria(req.categoriaId(), produto);
        fornecedorService.validarExistente(req.fornecedorPrincipalId());

        BigDecimal preco = req.precoVenda();
        boolean cardapio = req.exibirNoCardapio();
        if (req.tipo().isVendavel()) {
            if (preco == null || preco.signum() <= 0) {
                throw new NegocioException("PRECO_VENDA_OBRIGATORIO", "Informe o preço de venda para produtos vendáveis.");
            }
        } else {
            // Ingrediente puro não é vendido nem aparece no cardápio.
            preco = null;
            cardapio = false;
        }

        String codigo = req.codigoInterno() == null || req.codigoInterno().isBlank() ? null : req.codigoInterno().trim();
        if (codigo != null && produtoRepository.existsByCodigoInternoIgnoreCaseAndIdNot(codigo, produto.getId())) {
            throw new NegocioException("CODIGO_INTERNO_DUPLICADO", "Já existe um produto com o código " + codigo + ".");
        }

        String descricao = req.descricao() == null || req.descricao().isBlank() ? null : req.descricao().trim();
        produto.atualizarDados(req.nome().trim(), descricao, categoria, req.tipo(), unidade, req.custoMedio(), preco,
                req.estoqueMinimo(), req.fornecedorPrincipalId(), codigo, cardapio);
        produto.sincronizarEmbalagens(embalagens(req.embalagens(), novo));

        boolean controla = req.controlarEstoque();
        if (!controla && !novo && produto.isControlaEstoque() && estoqueService.quantidade(produto.getId()).signum() != 0) {
            throw new NegocioException("PRODUTO_COM_SALDO",
                    "Zere o estoque de " + produto.getNome() + " antes de desligar o controle de estoque.");
        }
        produto.definirControleEstoque(controla);
    }

    private List<Produto.DadosEmbalagem> embalagens(List<ProdutoDto.EmbalagemRequest> itens, boolean novo) {
        if (itens == null) {
            return List.of();
        }
        Set<String> descricoes = new HashSet<>();
        List<Produto.DadosEmbalagem> dados = new ArrayList<>();
        for (ProdutoDto.EmbalagemRequest item : itens) {
            String descricao = item.descricao().trim();
            if (!descricoes.add(descricao.toLowerCase())) {
                throw new NegocioException("EMBALAGEM_DUPLICADA", "Embalagem repetida: " + descricao + ".");
            }
            UnidadeMedida unidade = unidadeRepository.findById(item.unidadeId())
                    .orElseThrow(() -> new NegocioException("UNIDADE_INVALIDA", "Unidade da embalagem não existe."));
            if (!unidade.isEmbalagem()) {
                throw new NegocioException("EMBALAGEM_INVALIDA",
                        "Embalagens devem usar unidades do tipo embalagem (caixa, pacote...). "
                                + "Conversões como kg → g são automáticas.");
            }
            dados.add(new Produto.DadosEmbalagem(novo ? null : item.id(), unidade, descricao, item.fator()));
        }
        return dados;
    }

    private Categoria categoria(UUID categoriaId, Produto produto) {
        if (categoriaId == null) {
            return null;
        }
        Categoria categoria = categoriaRepository.findById(categoriaId)
                .orElseThrow(() -> new NegocioException("CATEGORIA_INVALIDA", "Categoria informada não existe."));
        boolean mesmaCategoria = produto.getCategoria() != null && produto.getCategoria().getId().equals(categoriaId);
        if (!categoria.isAtivo() && !mesmaCategoria) {
            throw new NegocioException("CATEGORIA_INATIVA", "A categoria " + categoria.getNome() + " está inativa.");
        }
        return categoria;
    }

    private UnidadeMedida unidadeEstoque(UUID unidadeId) {
        UnidadeMedida unidade = unidadeRepository.findById(unidadeId)
                .orElseThrow(() -> new NegocioException("UNIDADE_INVALIDA", "Unidade de medida não existe."));
        if (!unidade.isUnidadeBase()) {
            throw new NegocioException("UNIDADE_ESTOQUE_INVALIDA",
                    "A unidade de estoque deve ser uma unidade base (un, g ou ml). "
                            + "Compras em kg, litro, caixa ou pacote são convertidas automaticamente.");
        }
        return unidade;
    }

    private Produto carregar(UUID id) {
        return produtoRepository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Produto", id));
    }

    private ProdutoDto.Response resposta(Produto produto) {
        return ProdutoDto.Response.of(produto, estoqueService.quantidade(produto.getId()));
    }
}
