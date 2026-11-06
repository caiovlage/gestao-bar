package br.com.bar.gestao.venda.domain;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface VendaRepository extends JpaRepository<Venda, UUID> {

    Optional<Venda> findByChaveIdempotencia(UUID chaveIdempotencia);

    @Query(value = "select nextval('venda_numero_seq')", nativeQuery = true)
    long proximoNumero();

    /** Trava a venda (evita dois cancelamentos simultâneos). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select v from Venda v where v.id = :id")
    Optional<Venda> travar(@Param("id") UUID id);
}
