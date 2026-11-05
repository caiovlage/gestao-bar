package br.com.bar.gestao.catalogo.api;

import br.com.bar.gestao.catalogo.api.dto.ProdutoDto;
import br.com.bar.gestao.catalogo.application.ProdutoService;
import br.com.bar.gestao.catalogo.domain.TipoProduto;
import br.com.bar.gestao.shared.api.PageResponse;
import br.com.bar.gestao.shared.api.StatusRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/admin/produtos")
@Tag(name = "Produtos")
public class ProdutoController {

    private final ProdutoService service;

    public ProdutoController(ProdutoService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Pesquisa produtos por nome/código, categoria, tipo e status (paginado)")
    public PageResponse<ProdutoDto.Response> pesquisar(
            @RequestParam(required = false) String nome,
            @RequestParam(required = false) UUID categoriaId,
            @RequestParam(required = false) TipoProduto tipo,
            @RequestParam(required = false) Boolean ativo,
            @PageableDefault(sort = "nome", direction = Sort.Direction.ASC) Pageable pageable) {
        var filtro = new ProdutoService.Filtro(nome, categoriaId, tipo, ativo);
        return PageResponse.of(service.pesquisar(filtro, pageable), r -> r);
    }

    @GetMapping("/{id}")
    public ProdutoDto.Response buscar(@PathVariable UUID id) {
        return service.buscar(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProdutoDto.Response criar(@Valid @RequestBody ProdutoDto.Request request) {
        return service.criar(request);
    }

    @PutMapping("/{id}")
    public ProdutoDto.Response atualizar(@PathVariable UUID id, @Valid @RequestBody ProdutoDto.Request request) {
        return service.atualizar(id, request);
    }

    @PatchMapping("/{id}/status")
    @Operation(summary = "Ativa ou inativa o produto")
    public ProdutoDto.Response alterarStatus(@PathVariable UUID id, @Valid @RequestBody StatusRequest request) {
        return service.alterarStatus(id, request.ativo());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Exclui o produto (bloqueado se houver movimentações; nesse caso, inative)")
    public void excluir(@PathVariable UUID id) {
        service.excluir(id);
    }

    @PostMapping(path = "/{id}/imagem", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Envia/substitui a imagem do produto (JPG, PNG ou WEBP, até 5 MB)")
    public ProdutoDto.Response enviarImagem(@PathVariable UUID id, @RequestPart("arquivo") MultipartFile arquivo) {
        return service.definirImagem(id, arquivo);
    }

    @DeleteMapping("/{id}/imagem")
    public ProdutoDto.Response removerImagem(@PathVariable UUID id) {
        return service.removerImagem(id);
    }
}
