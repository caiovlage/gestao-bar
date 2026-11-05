package br.com.bar.gestao.catalogo.domain;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface UnidadeMedidaRepository extends JpaRepository<UnidadeMedida, UUID> {

    boolean existsBySiglaIgnoreCase(String sigla);
}
