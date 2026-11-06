package br.com.bar.gestao.receita.application;

import br.com.bar.gestao.receita.api.dto.ReceitaDto;
import br.com.bar.gestao.receita.domain.Receita;
import br.com.bar.gestao.receita.domain.ReceitaRepository;
import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.shared.exception.RecursoNaoEncontradoException;
import br.com.bar.gestao.shared.storage.ImagemStorageService;
import br.com.bar.gestao.shared.texto.HtmlSeguro;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

/** Cadastro de receitas para consulta rápida (sem vínculo com produtos ou estoque). */
@Service
public class ReceitaService {

    private static final Logger log = LoggerFactory.getLogger(ReceitaService.class);
    private static final int LIMITE_TEXTO = 100_000;

    private final ReceitaRepository repository;
    private final ImagemStorageService imagens;

    public ReceitaService(ReceitaRepository repository, ImagemStorageService imagens) {
        this.repository = repository;
        this.imagens = imagens;
    }

    @Transactional(readOnly = true)
    public Page<ReceitaDto.Resumo> pesquisar(String nome, Pageable pageable) {
        String termo = nome == null ? "" : nome.trim();
        return repository.findByNomeContainingIgnoreCase(termo, pageable).map(ReceitaDto.Resumo::of);
    }

    @Transactional(readOnly = true)
    public ReceitaDto.Detalhe buscar(UUID id) {
        return ReceitaDto.Detalhe.of(carregar(id));
    }

    @Transactional
    public ReceitaDto.Detalhe criar(ReceitaDto.Request req) {
        Receita receita = new Receita(req.nome().trim());
        aplicar(receita, req);
        repository.save(receita);
        log.info("Receita criada: id={} nome={}", receita.getId(), receita.getNome());
        return ReceitaDto.Detalhe.of(receita);
    }

    @Transactional
    public ReceitaDto.Detalhe atualizar(UUID id, ReceitaDto.Request req) {
        Receita receita = carregar(id);
        aplicar(receita, req);
        log.info("Receita atualizada: id={}", id);
        return ReceitaDto.Detalhe.of(receita);
    }

    @Transactional
    public void excluir(UUID id) {
        Receita receita = carregar(id);
        String foto = receita.getFotoUrl();
        repository.delete(receita);
        imagens.removerPorUrl(foto);
        log.info("Receita excluída: id={} nome={}", id, receita.getNome());
    }

    @Transactional
    public ReceitaDto.Detalhe definirFoto(UUID id, MultipartFile arquivo) {
        Receita receita = carregar(id);
        String anterior = receita.getFotoUrl();
        receita.definirFoto(imagens.salvar(arquivo));
        imagens.removerPorUrl(anterior);
        return ReceitaDto.Detalhe.of(receita);
    }

    @Transactional
    public ReceitaDto.Detalhe removerFoto(UUID id) {
        Receita receita = carregar(id);
        imagens.removerPorUrl(receita.getFotoUrl());
        receita.definirFoto(null);
        return ReceitaDto.Detalhe.of(receita);
    }

    private void aplicar(Receita receita, ReceitaDto.Request req) {
        String nome = req.nome().trim();
        if (repository.existsByNomeIgnoreCaseAndIdNot(nome, receita.getId())) {
            throw new NegocioException("RECEITA_DUPLICADA", "Já existe uma receita chamada " + nome + ".");
        }
        receita.atualizar(nome, texto(req.rendimento()), req.tempoPreparoMin(),
                html(req.ingredientes(), "ingredientes"), html(req.modoPreparo(), "modo de preparo"));
    }

    /** Limpa o HTML (remove scripts, cores, fontes, links) mantendo a formatação de leitura. */
    private static String html(String valor, String campo) {
        String limpo = HtmlSeguro.limpar(valor);
        if (limpo != null && limpo.length() > LIMITE_TEXTO) {
            throw new NegocioException("TEXTO_MUITO_LONGO", "O texto de " + campo + " é longo demais.");
        }
        return limpo;
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }

    private Receita carregar(UUID id) {
        return repository.findById(id).orElseThrow(() -> new RecursoNaoEncontradoException("Receita", id));
    }
}
