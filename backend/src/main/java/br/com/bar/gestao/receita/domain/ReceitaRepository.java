package br.com.bar.gestao.receita.domain;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface ReceitaRepository extends JpaRepository<Receita, UUID> {

    boolean existsByNomeIgnoreCaseAndIdNot(String nome, UUID id);

    Page<Receita> findByNomeContainingIgnoreCase(String nome, Pageable pageable);
}
