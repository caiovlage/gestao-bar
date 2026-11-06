package br.com.bar.gestao.pedido.domain;

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

public interface PedidoRepository extends JpaRepository<Pedido, UUID> {

    Optional<Pedido> findByChaveIdempotencia(UUID chave);

    @Query(value = "select nextval('pedido_numero_seq')", nativeQuery = true)
    long proximoNumero();

    /** Trava o pedido: impede, por exemplo, registrar o pagamento duas vezes ao mesmo tempo. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Pedido p where p.id = :id")
    Optional<Pedido> travar(@Param("id") UUID id);

    /** Pedidos em andamento: não cancelados e não (entregues e pagos). Mais antigos primeiro. */
    @Query("""
            select p from Pedido p
            where p.statusPreparo <> :cancelado
              and not (p.statusPreparo = :entregue and p.statusFinanceiro = :pago)
            order by p.criadoEm
            """)
    List<Pedido> emAndamento(@Param("cancelado") Pedido.StatusPreparo cancelado,
                             @Param("entregue") Pedido.StatusPreparo entregue,
                             @Param("pago") Pedido.StatusFinanceiro pago);

    Page<Pedido> findAllByOrderByCriadoEmDesc(Pageable pageable);

    long countByStatusPreparo(Pedido.StatusPreparo status);

    long countByStatusPreparoAndStatusFinanceiro(Pedido.StatusPreparo preparo, Pedido.StatusFinanceiro financeiro);
}
