package br.com.bar.gestao.shared.texto;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.safety.Safelist;

/**
 * Limpa HTML vindo do editor (inclusive conteúdo colado de sites), mantendo apenas a
 * formatação de leitura: parágrafos, quebras, negrito, itálico, sublinhado, títulos e listas.
 * Remove scripts, estilos, cores, fontes, imagens, links e atributos — o resultado é seguro
 * para armazenar e exibir, e todas as receitas ficam com a mesma aparência.
 */
public final class HtmlSeguro {

    private static final Safelist PERMITIDO = new Safelist()
            .addTags("p", "br", "b", "strong", "i", "em", "u", "h1", "h2", "h3", "h4",
                    "ul", "ol", "li", "blockquote");

    private static final Document.OutputSettings SAIDA = new Document.OutputSettings().prettyPrint(false);

    private HtmlSeguro() {
    }

    /** Retorna o HTML limpo, ou null se não sobrar texto. */
    public static String limpar(String html) {
        if (html == null || html.isBlank()) {
            return null;
        }
        Document doc = Jsoup.parseBodyFragment(html);
        doc.outputSettings(SAIDA);
        // Blocos de layout (o Chrome cria um <div> por linha ao editar) viram parágrafos,
        // senão as linhas grudariam umas nas outras ao remover as tags não permitidas.
        doc.select("div, section, article, header, footer, figure, tr, dt, dd").tagName("p");
        doc.select("h5, h6").tagName("h4");
        doc.select("td, th").append(" ");
        String limpo = Jsoup.clean(doc.body().html(), "", PERMITIDO, SAIDA).trim();
        return Jsoup.parseBodyFragment(limpo).text().isBlank() ? null : limpo;
    }

    /** Texto puro (sem tags), útil para buscas e resumos. */
    public static String texto(String html) {
        return html == null ? "" : Jsoup.parseBodyFragment(html).text();
    }
}
