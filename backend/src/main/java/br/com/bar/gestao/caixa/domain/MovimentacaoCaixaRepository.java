package br.com.bar.gestao.caixa.domain;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface MovimentacaoCaixaRepository extends JpaRepository<MovimentacaoCaixa, UUID> {

    List<MovimentacaoCaixa> findByCaixaIdOrderByDataHora(UUID caixaId);
}
