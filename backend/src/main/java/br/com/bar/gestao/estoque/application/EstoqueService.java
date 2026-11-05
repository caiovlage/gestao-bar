package br.com.bar.gestao.estoque.application;

import br.com.bar.gestao.estoque.domain.Estoque;
import br.com.bar.gestao.estoque.domain.EstoqueRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Ponto único de acesso ao saldo de estoque. Na Etapa 2 receberá as operações de
 * movimentação (entrada, saída, perda, inventário), com bloqueio pessimista por produto.
 */
@Service
public class EstoqueService {

    private final EstoqueRepository repository;

    public EstoqueService(EstoqueRepository repository) {
        this.repository = repository;
    }

    /** Cria o registro de saldo zerado para um novo produto (dentro da transação do cadastro). */
    @Transactional(propagation = Propagation.MANDATORY)
    public void inicializar(UUID produtoId) {
        if (!repository.existsById(produtoId)) {
            repository.save(new Estoque(produtoId));
        }
    }

    @Transactional(readOnly = true)
    public BigDecimal quantidade(UUID produtoId) {
        return repository.findById(produtoId).map(Estoque::getQuantidade).orElse(BigDecimal.ZERO);
    }

    @Transactional(readOnly = true)
    public Map<UUID, BigDecimal> quantidades(Collection<UUID> produtoIds) {
        return repository.findAllById(produtoIds).stream()
                .collect(Collectors.toMap(Estoque::getProdutoId, Estoque::getQuantidade));
    }
}
