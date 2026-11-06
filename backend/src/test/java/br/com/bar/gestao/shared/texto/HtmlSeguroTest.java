package br.com.bar.gestao.shared.texto;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class HtmlSeguroTest {

    @Test
    void mantemFormatacaoDeLeitura() {
        String html = "<h2>Preparo</h2><p>Frite a <strong>batata</strong> em <em>óleo quente</em>.</p>"
                + "<ol><li>Escorra</li><li>Salgue</li></ol>";
        assertThat(HtmlSeguro.limpar(html)).isEqualTo(html);
    }

    @Test
    void removeScriptsEstilosELinksDeConteudoColado() {
        String colado = "<div style=\"color:red;font-family:Comic Sans\"><span class=\"x\">Misture</span> "
                + "<b onclick=\"alert(1)\">bem</b><script>alert('x')</script>"
                + "<a href=\"https://site.com\">veja</a><img src=x onerror=alert(1)></div>";
        String limpo = HtmlSeguro.limpar(colado);

        assertThat(limpo).isEqualTo("<p>Misture <b>bem</b>veja</p>");
        assertThat(limpo).doesNotContain("script", "style", "onclick", "href", "img", "onerror");
    }

    @Test
    void divsDoEditorViramParagrafos() {
        // O Chrome cria uma <div> por linha no modo de edição.
        assertThat(HtmlSeguro.limpar("Linha 1<div>Linha 2</div><div><br></div><div>Linha 3</div>"))
                .isEqualTo("Linha 1<p>Linha 2</p><p><br></p><p>Linha 3</p>");
    }

    @Test
    void conteudoSemTextoViraNulo() {
        assertThat(HtmlSeguro.limpar("<p><br></p><div> </div>")).isNull();
        assertThat(HtmlSeguro.limpar(null)).isNull();
        assertThat(HtmlSeguro.limpar("<script>alert(1)</script>")).isNull();
    }
}
