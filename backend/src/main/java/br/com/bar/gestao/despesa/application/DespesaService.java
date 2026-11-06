package br.com.bar.gestao.despesa.application;

import br.com.bar.gestao.despesa.api.dto.DespesaDto;
import br.com.bar.gestao.despesa.domain.Despesa;
import br.com.bar.gestao.despesa.domain.DespesaRepository;
import br.com.bar.gestao.fornecedor.application.FornecedorService;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class DespesaService {

    private static final Logger log = LoggerFactory.getLogger(DespesaService.class);

    private final DespesaRepository repository;
    private final FornecedorService fornecedores;

    public DespesaService(DespesaRepository repository, FornecedorService fornecedores) {
        this.repository = repository;
        this.fornecedores = fornecedores;
    }

    @Transactional(readOnly = true)
    public DespesaDto.Lista listar(LocalDate inicio, LocalDate fim) {
        List<Despesa> despesas = repository.findByDataBetween(inicio, fim, Sort.by(Sort.Direction.DESC, "data"));
        Map<Despesa.Categoria, BigDecimal> porCategoria = new EnumMap<>(Despesa.Categoria.class);
        BigDecimal total = BigDecimal.ZERO;
        for (Despesa d : despesas) {
            porCategoria.merge(d.getCategoria(), d.getValor(), BigDecimal::add);
            total = total.add(d.getValor());
        }
        return new DespesaDto.Lista(despesas.stream().map(this::resposta).toList(), total,
                porCategoria.entrySet().stream()
                        .map(e -> new DespesaDto.TotalCategoria(e.getKey(), e.getValue()))
                        .sorted(Comparator.comparing(DespesaDto.TotalCategoria::total).reversed())
                        .toList());
    }

    @Transactional
    public DespesaDto.Response criar(DespesaDto.Request req) {
        Despesa d = new Despesa(req.descricao().trim());
        aplicar(d, req);
        repository.save(d);
        log.info("Despesa registrada: {} {} em {}", d.getDescricao(), d.getValor(), d.getData());
        return resposta(d);
    }

    @Transactional
    public DespesaDto.Response atualizar(UUID id, DespesaDto.Request req) {
        Despesa d = carregar(id);
        aplicar(d, req);
        return resposta(d);
    }

    @Transactional
    public void excluir(UUID id) {
        repository.delete(carregar(id));
        log.info("Despesa excluída: id={}", id);
    }

    private void aplicar(Despesa d, DespesaDto.Request req) {
        fornecedores.validarExistente(req.fornecedorId());
        d.atualizar(req.descricao().trim(), req.categoria(), req.valor(), req.data(), req.fornecedorId(),
                req.observacao() == null || req.observacao().isBlank() ? null : req.observacao().trim());
    }

    private DespesaDto.Response resposta(Despesa d) {
        return new DespesaDto.Response(d.getId(), d.getDescricao(), d.getCategoria(), d.getValor(), d.getData(),
                d.getFornecedorId(), fornecedores.nome(d.getFornecedorId()), d.getObservacao());
    }

    private Despesa carregar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Despesa", id));
    }
}
