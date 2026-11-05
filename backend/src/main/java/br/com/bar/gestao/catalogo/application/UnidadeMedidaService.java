package br.com.bar.gestao.catalogo.application;

import br.com.bar.gestao.catalogo.api.dto.UnidadeMedidaDto;
import br.com.bar.gestao.catalogo.domain.Grandeza;
import br.com.bar.gestao.catalogo.domain.UnidadeMedida;
import br.com.bar.gestao.catalogo.domain.UnidadeMedidaRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class UnidadeMedidaService {

    private static final Logger log = LoggerFactory.getLogger(UnidadeMedidaService.class);

    private final UnidadeMedidaRepository repository;

    public UnidadeMedidaService(UnidadeMedidaRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public List<UnidadeMedida> listar() {
        return repository.findAll(Sort.by("grandeza", "fatorBase", "sigla"));
    }

    @Transactional(readOnly = true)
    public UnidadeMedida buscar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Unidade de medida", id));
    }

    @Transactional
    public UnidadeMedida criar(UnidadeMedidaDto.Request req) {
        String sigla = req.sigla().trim();
        if (repository.existsBySiglaIgnoreCase(sigla)) {
            throw new NegocioException("UNIDADE_DUPLICADA", "Já existe uma unidade com a sigla " + sigla + ".");
        }
        if (req.grandeza() != Grandeza.EMBALAGEM && req.fatorBase() == null) {
            throw new NegocioException("FATOR_OBRIGATORIO",
                    "Informe quantas unidades base (g, ml ou un) correspondem a 1 " + sigla + ".");
        }
        UnidadeMedida unidade = repository.save(new UnidadeMedida(sigla, req.nome().trim(), req.grandeza(), req.fatorBase()));
        log.info("Unidade de medida criada: {} ({})", sigla, req.grandeza());
        return unidade;
    }
}
