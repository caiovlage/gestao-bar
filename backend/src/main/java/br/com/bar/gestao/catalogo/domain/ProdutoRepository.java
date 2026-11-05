package br.com.bar.gestao.catalogo.domain;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.UUID;

public interface ProdutoRepository extends JpaRepository<Produto, UUID>, JpaSpecificationExecutor<Produto> {

    @Override
    @EntityGraph(attributePaths = {"categoria", "unidadeEstoque"})
    Page<Produto> findAll(Specification<Produto> spec, Pageable pageable);

    boolean existsByCodigoInternoIgnoreCaseAndIdNot(String codigoInterno, UUID id);
}
