package br.com.bar.gestao.estoque.domain;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface InventarioRepository extends JpaRepository<Inventario, UUID> {

    boolean existsByStatus(Inventario.Status status);
}
