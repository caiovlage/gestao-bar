package br.com.bar.gestao.estoque.domain;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface MovimentacaoEstoqueRepository extends JpaRepository<MovimentacaoEstoque, UUID> {

    boolean existsByProdutoId(UUID produtoId);
}
