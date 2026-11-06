package br.com.bar.gestao.fornecedor.application;

import br.com.bar.gestao.fornecedor.api.FornecedorRequest;
import br.com.bar.gestao.fornecedor.domain.Fornecedor;
import br.com.bar.gestao.fornecedor.domain.FornecedorRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import jakarta.persistence.criteria.Predicate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class FornecedorService {

    private static final Logger log = LoggerFactory.getLogger(FornecedorService.class);

    private final FornecedorRepository repository;

    public FornecedorService(FornecedorRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public Page<Fornecedor> pesquisar(String nome, Boolean ativo, Pageable pageable) {
        Specification<Fornecedor> spec = (root, query, cb) -> {
            List<Predicate> p = new ArrayList<>();
            if (nome != null && !nome.isBlank()) {
                String termo = "%" + nome.trim().toLowerCase() + "%";
                p.add(cb.or(cb.like(cb.lower(root.get("nome")), termo),
                        cb.like(cb.lower(root.get("nomeFantasia")), termo)));
            }
            if (ativo != null) {
                p.add(cb.equal(root.get("ativo"), ativo));
            }
            return cb.and(p.toArray(Predicate[]::new));
        };
        return repository.findAll(spec, pageable);
    }

    @Transactional(readOnly = true)
    public Fornecedor buscar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Fornecedor", id));
    }

    /** Nome de exibição do fornecedor (para outros módulos), ou null se não existir. */
    @Transactional(readOnly = true)
    public String nome(UUID id) {
        if (id == null) return null;
        return repository.findById(id).map(f -> f.getNomeFantasia() != null ? f.getNomeFantasia() : f.getNome()).orElse(null);
    }

    /** Usado por outros módulos (produtos, compras) para validar a referência. */
    @Transactional(readOnly = true)
    public void validarExistente(UUID id) {
        if (id != null && !repository.existsById(id)) {
            throw new NegocioException("FORNECEDOR_INVALIDO", "Fornecedor informado não existe.");
        }
    }

    @Transactional
    public Fornecedor criar(FornecedorRequest req) {
        Fornecedor f = new Fornecedor(req.nome().trim());
        aplicar(f, req);
        repository.save(f);
        log.info("Fornecedor criado: id={} nome={}", f.getId(), f.getNome());
        return f;
    }

    @Transactional
    public Fornecedor atualizar(UUID id, FornecedorRequest req) {
        Fornecedor f = buscar(id);
        aplicar(f, req);
        log.info("Fornecedor atualizado: id={}", id);
        return f;
    }

    @Transactional
    public Fornecedor alterarStatus(UUID id, boolean ativo) {
        Fornecedor f = buscar(id);
        f.alterarStatus(ativo);
        log.info("Fornecedor {}: id={}", ativo ? "ativado" : "inativado", id);
        return f;
    }

    private void aplicar(Fornecedor f, FornecedorRequest req) {
        String cnpj = somenteDigitos(req.cnpj());
        if (cnpj != null && repository.existsByCnpjAndIdNot(cnpj, f.getId())) {
            throw new NegocioException("CNPJ_DUPLICADO", "Já existe um fornecedor com este CNPJ.");
        }
        f.atualizar(req.nome().trim(), vazioParaNulo(req.nomeFantasia()), cnpj, vazioParaNulo(req.telefone()),
                vazioParaNulo(req.email()), vazioParaNulo(req.endereco()), vazioParaNulo(req.observacoes()));
    }

    private static String somenteDigitos(String valor) {
        if (valor == null) return null;
        String digitos = valor.replaceAll("\\D", "");
        return digitos.isEmpty() ? null : digitos;
    }

    private static String vazioParaNulo(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
