package br.com.bar.gestao.compra.domain;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface CompraRepository extends JpaRepository<Compra, UUID> {

    @Query(value = "select nextval('compra_numero_seq')", nativeQuery = true)
    long proximoNumero();

    Page<Compra> findByStatus(Compra.Status status, Pageable pageable);

    /** Trava a compra (evita dois recebimentos simultâneos da mesma lista). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Compra c where c.id = :id")
    Optional<Compra> travar(@Param("id") UUID id);
}
