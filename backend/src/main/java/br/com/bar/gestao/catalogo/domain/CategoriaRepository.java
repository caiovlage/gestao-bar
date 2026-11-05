package br.com.bar.gestao.catalogo.domain;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface CategoriaRepository extends JpaRepository<Categoria, UUID> {

    List<Categoria> findByAtivo(boolean ativo, Sort sort);

    boolean existsByNomeIgnoreCaseAndIdNot(String nome, UUID id);
}
