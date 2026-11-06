-- =====================================================================
-- Cardápio com destaques: preço promocional (com término opcional) e
-- "sugestão da casa". Os mais pedidos são calculados das vendas.
-- =====================================================================

ALTER TABLE produto ADD COLUMN preco_promocional NUMERIC(14,2) CHECK (preco_promocional > 0);
-- último dia da promoção (inclusive), no fuso do bar; nulo = sem data para acabar
ALTER TABLE produto ADD COLUMN promocao_ate DATE;
ALTER TABLE produto ADD COLUMN destaque_cardapio BOOLEAN NOT NULL DEFAULT FALSE;

-- Vitrine do cardápio: seções de destaque configuráveis no painel (quais aparecem, ordem,
-- título e quantidade de produtos). O conteúdo de cada seção é calculado automaticamente,
-- exceto "Sugestões da casa", que usa os produtos marcados no cadastro.
CREATE TABLE vitrine_secao (
    tipo       VARCHAR(20) PRIMARY KEY CHECK (tipo IN
                   ('SUGESTOES', 'PROMOCOES', 'MAIS_PEDIDOS', 'MENOS_PEDIDOS', 'NOVIDADES')),
    titulo     VARCHAR(60) NOT NULL,
    ativa      BOOLEAN     NOT NULL,
    ordem      INT         NOT NULL,
    quantidade INT         NOT NULL CHECK (quantidade BETWEEN 1 AND 12)
);

INSERT INTO vitrine_secao (tipo, titulo, ativa, ordem, quantidade) VALUES
    ('SUGESTOES',     'Sugestões da casa',  TRUE,  1, 8),
    ('PROMOCOES',     'Promoções',          TRUE,  2, 8),
    ('MAIS_PEDIDOS',  'Mais pedidos',       TRUE,  3, 6),
    ('NOVIDADES',     'Novidades',          FALSE, 4, 6),
    ('MENOS_PEDIDOS', 'Experimente também', FALSE, 5, 6);
