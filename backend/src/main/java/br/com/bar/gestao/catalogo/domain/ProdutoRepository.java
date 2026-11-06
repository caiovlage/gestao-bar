package br.com.bar.gestao.catalogo.domain;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ProdutoRepository extends JpaRepository<Produto, UUID>, JpaSpecificationExecutor<Produto> {

    @Override
    @EntityGraph(attributePaths = {"categoria", "unidadeEstoque"})
    Page<Produto> findAll(Specification<Produto> spec, Pageable pageable);

    boolean existsByCodigoInternoIgnoreCaseAndIdNot(String codigoInterno, UUID id);

    Optional<Produto> findByCodigoInternoIgnoreCase(String codigoInterno);

    @EntityGraph(attributePaths = {"categoria", "unidadeEstoque"})
    List<Produto> findByIdIn(Collection<UUID> ids);

    @Query("select p.id from Produto p where p.ativo = true")
    List<UUID> findIdsAtivos();

    @Query("select p.id from Produto p where p.ativo = true and p.categoria.id = :categoriaId")
    List<UUID> findIdsAtivosPorCategoria(@Param("categoriaId") UUID categoriaId);
}
