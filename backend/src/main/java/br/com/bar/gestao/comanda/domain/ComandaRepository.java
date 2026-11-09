package br.com.bar.gestao.comanda.domain;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ComandaRepository extends JpaRepository<Comanda, UUID> {

    @Query(value = "select nextval('comanda_numero_seq')", nativeQuery = true)
    long proximoNumero();

    /** Trava a comanda: lançamentos e fechamento simultâneos não se atropelam. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Comanda c where c.id = :id")
    Optional<Comanda> travar(@Param("id") UUID id);

    List<Comanda> findByStatusOrderByCriadoEm(Comanda.Status status);

    Page<Comanda> findByStatusNotOrderByCriadoEmDesc(Comanda.Status status, Pageable pageable);
}
