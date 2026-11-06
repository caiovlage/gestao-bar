package br.com.bar.gestao.compra.application;

import br.com.bar.gestao.compra.api.dto.CompraDto;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.DataFormat;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.openpdf.text.Document;
import org.openpdf.text.Element;
import org.openpdf.text.FontFactory;
import org.openpdf.text.PageSize;
import org.openpdf.text.Paragraph;
import org.openpdf.text.Phrase;
import org.openpdf.text.pdf.PdfPCell;
import org.openpdf.text.pdf.PdfPTable;
import org.openpdf.text.pdf.PdfWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/** Exporta a lista de compras para PDF (impressão/WhatsApp) e Excel (edição). */
@Component
public class CompraExportacao {

    private static final Locale PT_BR = Locale.of("pt", "BR");
    private static final DateTimeFormatter DATA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private final ZoneId fuso;

    public CompraExportacao(@Value("${app.fuso-horario}") String fuso) {
        this.fuso = ZoneId.of(fuso);
    }

    public byte[] pdf(CompraDto.Response c) {
        ByteArrayOutputStream saida = new ByteArrayOutputStream();
        Document doc = new Document(PageSize.A4, 36, 36, 36, 36);
        PdfWriter.getInstance(doc, saida);
        doc.open();

        doc.add(new Paragraph("Lista de compras nº " + c.numero(), FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16)));
        org.openpdf.text.Font normal = FontFactory.getFont(FontFactory.HELVETICA, 10);
        doc.add(new Paragraph("Fornecedor: " + (c.fornecedor() == null ? "—" : c.fornecedor()), normal));
        doc.add(new Paragraph("Data: " + DATA.format(c.criadaEm().atZone(fuso)), normal));
        if (c.observacao() != null) doc.add(new Paragraph("Obs.: " + c.observacao(), normal));
        doc.add(new Paragraph(" "));

        PdfPTable tabela = new PdfPTable(new float[]{5, 2, 2.4f, 2, 2});
        tabela.setWidthPercentage(100);
        org.openpdf.text.Font negrito = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10);
        for (String titulo : new String[]{"Produto", "Quantidade", "Unidade", "Preço unit.", "Total"}) {
            PdfPCell cel = new PdfPCell(new Phrase(titulo, negrito));
            cel.setBackgroundColor(new Color(245, 158, 11));
            cel.setPadding(5);
            tabela.addCell(cel);
        }
        for (CompraDto.ItemResponse i : c.itens()) {
            tabela.addCell(celula(i.produtoNome(), normal, Element.ALIGN_LEFT));
            tabela.addCell(celula(numero(i.quantidade()), normal, Element.ALIGN_RIGHT));
            tabela.addCell(celula(i.unidadeCompra(), normal, Element.ALIGN_LEFT));
            tabela.addCell(celula(moeda(i.custoUnitario()), normal, Element.ALIGN_RIGHT));
            tabela.addCell(celula(moeda(i.custoTotal()), normal, Element.ALIGN_RIGHT));
        }
        PdfPCell rotulo = celula("Total estimado", negrito, Element.ALIGN_RIGHT);
        rotulo.setColspan(4);
        tabela.addCell(rotulo);
        tabela.addCell(celula(moeda(c.total()), negrito, Element.ALIGN_RIGHT));
        doc.add(tabela);
        doc.close();
        return saida.toByteArray();
    }

    public byte[] excel(CompraDto.Response c) {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream saida = new ByteArrayOutputStream()) {
            Sheet aba = wb.createSheet("Compra " + c.numero());
            DataFormat formato = wb.createDataFormat();
            Font fonteNegrito = wb.createFont();
            fonteNegrito.setBold(true);
            CellStyle cabecalho = wb.createCellStyle();
            cabecalho.setFont(fonteNegrito);
            cabecalho.setBorderBottom(BorderStyle.THIN);
            CellStyle dinheiro = wb.createCellStyle();
            dinheiro.setDataFormat(formato.getFormat("\"R$\" #,##0.00"));
            CellStyle quantidade = wb.createCellStyle();
            quantidade.setDataFormat(formato.getFormat("#,##0.###"));

            aba.createRow(0).createCell(0).setCellValue("Lista de compras nº " + c.numero());
            aba.createRow(1).createCell(0).setCellValue("Fornecedor: " + (c.fornecedor() == null ? "—" : c.fornecedor()));
            aba.createRow(2).createCell(0).setCellValue("Data: " + DATA.format(c.criadaEm().atZone(fuso)));

            Row titulos = aba.createRow(4);
            String[] colunas = {"Produto", "Quantidade", "Unidade", "Preço unitário", "Total"};
            for (int i = 0; i < colunas.length; i++) {
                titulos.createCell(i).setCellValue(colunas[i]);
                titulos.getCell(i).setCellStyle(cabecalho);
            }
            int linha = 5;
            for (CompraDto.ItemResponse i : c.itens()) {
                Row r = aba.createRow(linha++);
                r.createCell(0).setCellValue(i.produtoNome());
                r.createCell(1).setCellValue(i.quantidade().doubleValue());
                r.getCell(1).setCellStyle(quantidade);
                r.createCell(2).setCellValue(i.unidadeCompra());
                r.createCell(3).setCellValue(i.custoUnitario().doubleValue());
                r.getCell(3).setCellStyle(dinheiro);
                r.createCell(4).setCellFormula("B" + linha + "*D" + linha);
                r.getCell(4).setCellStyle(dinheiro);
            }
            Row total = aba.createRow(linha);
            total.createCell(3).setCellValue("Total");
            total.getCell(3).setCellStyle(cabecalho);
            total.createCell(4).setCellFormula(c.itens().isEmpty() ? "0" : "SUM(E6:E" + linha + ")");
            total.getCell(4).setCellStyle(dinheiro);
            for (int i = 0; i < colunas.length; i++) {
                aba.setColumnWidth(i, i == 0 ? 40 * 256 : 16 * 256);
            }
            wb.write(saida);
            return saida.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static PdfPCell celula(String texto, org.openpdf.text.Font fonte, int alinhamento) {
        PdfPCell cel = new PdfPCell(new Phrase(texto == null ? "" : texto, fonte));
        cel.setHorizontalAlignment(alinhamento);
        cel.setPadding(5);
        return cel;
    }

    private static String moeda(BigDecimal v) {
        return NumberFormat.getCurrencyInstance(PT_BR).format(v);
    }

    private static String numero(BigDecimal v) {
        return NumberFormat.getNumberInstance(PT_BR).format(v);
    }
}
