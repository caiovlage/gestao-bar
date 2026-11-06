package br.com.bar.gestao.caixa.domain;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface CaixaRepository extends JpaRepository<Caixa, UUID> {

    Optional<Caixa> findByStatus(Caixa.Status status);

    /**
     * Trava compartilhada (FOR SHARE): várias vendas simultâneas no mesmo caixa, mas o
     * fechamento (que usa FOR UPDATE) espera todas terminarem e impede novas até concluir.
     */
    @Lock(LockModeType.PESSIMISTIC_READ)
    @Query("select c from Caixa c where c.status = :status")
    Optional<Caixa> travarCompartilhadoPorStatus(@Param("status") Caixa.Status status);

    @Lock(LockModeType.PESSIMISTIC_READ)
    @Query("select c from Caixa c where c.id = :id")
    Optional<Caixa> travarCompartilhado(@Param("id") UUID id);

    /** Trava exclusiva (FOR UPDATE), usada no fechamento e nas movimentações de dinheiro. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Caixa c where c.id = :id")
    Optional<Caixa> travarExclusivo(@Param("id") UUID id);
}
