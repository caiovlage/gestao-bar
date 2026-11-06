package br.com.bar.gestao.pedido.application;

import br.com.bar.gestao.pedido.api.dto.VitrineDto;
import br.com.bar.gestao.shared.exception.NegocioException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/** Configuração da vitrine do cardápio (seções de destaque, ordem, títulos e quantidades). */
@Service
public class VitrineService {

    private static final Logger log = LoggerFactory.getLogger(VitrineService.class);

    private final JdbcClient jdbc;

    public VitrineService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public List<VitrineDto.Secao> listar() {
        return jdbc.sql("SELECT tipo, titulo, ativa, quantidade FROM vitrine_secao ORDER BY ordem")
                .query((rs, n) -> new VitrineDto.Secao(VitrineDto.TipoSecao.valueOf(rs.getString("tipo")),
                        rs.getString("titulo"), rs.getBoolean("ativa"), rs.getInt("quantidade")))
                .list();
    }

    @Transactional
    public List<VitrineDto.Secao> atualizar(List<VitrineDto.Secao> secoes) {
        Set<VitrineDto.TipoSecao> vistos = EnumSet.noneOf(VitrineDto.TipoSecao.class);
        for (VitrineDto.Secao s : secoes) {
            if (!vistos.add(s.tipo())) {
                throw new NegocioException("SECAO_DUPLICADA", "A seção " + s.tipo() + " foi informada mais de uma vez.");
            }
        }
        int ordem = 1;
        for (VitrineDto.Secao s : secoes) {
            jdbc.sql("""
                            UPDATE vitrine_secao SET titulo = :titulo, ativa = :ativa, quantidade = :quantidade, ordem = :ordem
                            WHERE tipo = :tipo
                            """)
                    .param("titulo", s.titulo().trim())
                    .param("ativa", s.ativa())
                    .param("quantidade", s.quantidade())
                    .param("ordem", ordem++)
                    .param("tipo", s.tipo().name())
                    .update();
        }
        // Seções não enviadas ficam no fim.
        for (VitrineDto.TipoSecao t : EnumSet.complementOf(EnumSet.copyOf(vistos))) {
            jdbc.sql("UPDATE vitrine_secao SET ordem = :ordem WHERE tipo = :tipo")
                    .param("ordem", ordem++).param("tipo", t.name()).update();
        }
        log.info("Vitrine do cardápio atualizada: {}", secoes.stream()
                .filter(VitrineDto.Secao::ativa).map(s -> s.tipo().name()).toList());
        return listar();
    }
}
