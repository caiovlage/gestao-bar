package br.com.bar.gestao.compra.domain;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface HistoricoCustoRepository extends JpaRepository<HistoricoCusto, UUID> {
}
