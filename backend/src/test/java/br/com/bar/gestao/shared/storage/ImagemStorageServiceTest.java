package br.com.bar.gestao.shared.storage;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

class ImagemStorageServiceTest {

    @Test
    void detectaFormatosPelaAssinatura() {
        byte[] jpg = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0};
        byte[] png = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
        byte[] webp = "RIFF\0\0\0\0WEBP".getBytes(StandardCharsets.ISO_8859_1);

        assertThat(ImagemStorageService.detectarExtensao(jpg)).contains("jpg");
        assertThat(ImagemStorageService.detectarExtensao(png)).contains("png");
        assertThat(ImagemStorageService.detectarExtensao(webp)).contains("webp");
    }

    @Test
    void rejeitaArquivoQueNaoEImagem() {
        byte[] html = "<html><script>".getBytes(StandardCharsets.UTF_8);
        assertThat(ImagemStorageService.detectarExtensao(html)).isEmpty();
    }

    @Test
    void naoCarregaNomesForaDoPadrao(@TempDir Path dir) {
        var storage = new ImagemStorageService(dir.toString());
        assertThat(storage.carregar("../application.yml")).isEmpty();
        assertThat(storage.carregar("qualquer.jpg")).isEmpty();
    }
}
