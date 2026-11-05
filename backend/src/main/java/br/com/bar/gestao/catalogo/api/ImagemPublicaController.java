package br.com.bar.gestao.catalogo.api;

import br.com.bar.gestao.shared.storage.ImagemStorageService;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;

/** Serve as imagens de produtos para o painel e para o cardápio público. */
@RestController
@RequestMapping("/api/public/imagens")
@Tag(name = "Público")
@SecurityRequirements
public class ImagemPublicaController {

    private final ImagemStorageService storage;

    public ImagemPublicaController(ImagemStorageService storage) {
        this.storage = storage;
    }

    @GetMapping("/{arquivo}")
    public ResponseEntity<Resource> imagem(@PathVariable String arquivo) {
        return storage.carregar(arquivo)
                .map(r -> ResponseEntity.ok()
                        // nomes são UUIDs: uma imagem nova sempre tem URL nova, então o cache pode ser longo
                        .cacheControl(CacheControl.maxAge(Duration.ofDays(30)).cachePublic().immutable())
                        .contentType(MediaTypeFactory.getMediaType(arquivo).orElse(MediaType.APPLICATION_OCTET_STREAM))
                        .<Resource>body(r))
                .orElse(ResponseEntity.notFound().build());
    }
}
