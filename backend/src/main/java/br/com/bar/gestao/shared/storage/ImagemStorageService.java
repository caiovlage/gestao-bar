package br.com.bar.gestao.shared.storage;

import br.com.bar.gestao.shared.exception.NegocioException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Armazena imagens (produtos, receitas) em disco local. Em Docker o diretório é um volume.
 * Aceita apenas JPEG, PNG e WEBP, validando a assinatura real do arquivo (não só a extensão).
 * O nome salvo é sempre um UUID gerado aqui, nunca o nome enviado pelo usuário.
 */
@Service
public class ImagemStorageService {

    private static final Logger log = LoggerFactory.getLogger(ImagemStorageService.class);
    private static final Pattern NOME_VALIDO = Pattern.compile("[0-9a-f-]{36}\\.(jpg|png|webp)");
    public static final String URL_PUBLICA = "/api/public/imagens/";

    private final Path diretorio;

    public ImagemStorageService(@Value("${app.upload-dir}") String uploadDir) {
        this.diretorio = Path.of(uploadDir).toAbsolutePath().normalize();
        try {
            Files.createDirectories(diretorio);
        } catch (IOException e) {
            throw new UncheckedIOException("Não foi possível criar o diretório de uploads: " + diretorio, e);
        }
    }

    /** Salva a imagem e retorna a URL pública relativa (ex.: /api/public/imagens/uuid.jpg). */
    public String salvar(MultipartFile arquivo) {
        if (arquivo == null || arquivo.isEmpty()) {
            throw new NegocioException("IMAGEM_INVALIDA", "Nenhuma imagem enviada.");
        }
        try (InputStream in = arquivo.getInputStream()) {
            byte[] cabecalho = in.readNBytes(12);
            String extensao = detectarExtensao(cabecalho)
                    .orElseThrow(() -> new NegocioException("IMAGEM_INVALIDA", "Formato não suportado. Use JPG, PNG ou WEBP."));
            String nome = UUID.randomUUID() + "." + extensao;
            arquivo.transferTo(diretorio.resolve(nome));
            log.info("Imagem salva: {}", nome);
            return URL_PUBLICA + nome;
        } catch (IOException e) {
            throw new UncheckedIOException("Falha ao salvar imagem", e);
        }
    }

    /** Remove a imagem a partir da URL pública. Ignora URLs que não pertencem a este armazenamento. */
    public void removerPorUrl(String url) {
        if (url == null || !url.startsWith(URL_PUBLICA)) {
            return;
        }
        String nome = url.substring(URL_PUBLICA.length());
        if (!NOME_VALIDO.matcher(nome).matches()) {
            return;
        }
        try {
            Files.deleteIfExists(diretorio.resolve(nome));
        } catch (IOException e) {
            log.warn("Não foi possível remover a imagem {}", nome, e);
        }
    }

    public Optional<Resource> carregar(String nome) {
        if (!NOME_VALIDO.matcher(nome).matches()) {
            return Optional.empty();
        }
        Path arquivo = diretorio.resolve(nome);
        if (!Files.isRegularFile(arquivo)) {
            return Optional.empty();
        }
        try {
            return Optional.of(new UrlResource(arquivo.toUri()));
        } catch (MalformedURLException e) {
            return Optional.empty();
        }
    }

    static Optional<String> detectarExtensao(byte[] b) {
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) {
            return Optional.of("jpg");
        }
        if (b.length >= 8 && Arrays.equals(Arrays.copyOf(b, 8),
                new byte[]{(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A})) {
            return Optional.of("png");
        }
        if (b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') {
            return Optional.of("webp");
        }
        return Optional.empty();
    }
}
