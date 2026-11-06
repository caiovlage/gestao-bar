package br.com.bar.gestao.estoque.domain;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface EstoqueRepository extends JpaRepository<Estoque, UUID> {

    /**
     * Bloqueia (SELECT ... FOR UPDATE) os saldos dos produtos até o fim da transação.
     * A ordenação por produto_id faz todas as transações travarem na mesma ordem,
     * evitando deadlocks quando duas operações envolvem os mesmos produtos.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Estoque e where e.produtoId in :ids order by e.produtoId")
    List<Estoque> travar(@Param("ids") Collection<UUID> ids);
}
