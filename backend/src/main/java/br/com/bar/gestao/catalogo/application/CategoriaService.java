package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.api.dto.CategoriaDto;
import br.com.bar.gestao.catalogo.domain.Categoria;
import br.com.bar.gestao.catalogo.domain.CategoriaRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class CategoriaService {

    private static final Logger log = LoggerFactory.getLogger(CategoriaService.class);
    private static final Sort ORDENACAO = Sort.by("ordem", "nome");

    private final CategoriaRepository repository;

    public CategoriaService(CategoriaRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public List<Categoria> listar(Boolean ativo) {
        return ativo == null ? repository.findAll(ORDENACAO) : repository.findByAtivo(ativo, ORDENACAO);
    }

    @Transactional(readOnly = true)
    public Categoria buscar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Categoria", id));
    }

    @Transactional
    public Categoria criar(CategoriaDto.Request req) {
        Categoria categoria = new Categoria(req.nome().trim(), ordem(req), exibir(req));
        validarNome(categoria.getNome(), categoria.getId());
        repository.save(categoria);
        log.info("Categoria criada: id={} nome={}", categoria.getId(), categoria.getNome());
        return categoria;
    }

    @Transactional
    public Categoria atualizar(UUID id, CategoriaDto.Request req) {
        Categoria categoria = buscar(id);
        validarNome(req.nome().trim(), id);
        categoria.atualizar(req.nome().trim(), ordem(req), exibir(req));
        log.info("Categoria atualizada: id={}", id);
        return categoria;
    }

    @Transactional
    public Categoria alterarStatus(UUID id, boolean ativo) {
        Categoria categoria = buscar(id);
        categoria.alterarStatus(ativo);
        log.info("Categoria {}: id={}", ativo ? "ativada" : "inativada", id);
        return categoria;
    }

    /** Exclusão física só é permitida para categorias sem produtos vinculados. */
    @Transactional
    public void excluir(UUID id) {
        Categoria categoria = buscar(id);
        try {
            repository.delete(categoria);
            repository.flush();
        } catch (DataIntegrityViolationException e) {
            throw new NegocioException("CATEGORIA_EM_USO",
                    "A categoria possui produtos vinculados. Inative-a em vez de excluir.");
        }
        log.info("Categoria excluída: id={} nome={}", id, categoria.getNome());
    }

    private void validarNome(String nome, UUID id) {
        if (repository.existsByNomeIgnoreCaseAndIdNot(nome, id)) {
            throw new NegocioException("CATEGORIA_DUPLICADA", "Já existe uma categoria com o nome " + nome + ".");
        }
    }

    private static int ordem(CategoriaDto.Request req) {
        return req.ordem() == null ? 0 : req.ordem();
    }

    private static boolean exibir(CategoriaDto.Request req) {
        return req.exibirCardapio() == null || req.exibirCardapio();
    }
}
