-- =====================================================================
-- Etapa 3 — Receitas para consulta rápida na cozinha.
-- Independentes de produtos e estoque: ingredientes e modo de preparo são
-- textos formatados (HTML limpo no servidor), que aceitam conteúdo colado de sites.
-- =====================================================================

CREATE TABLE receita (
    id                UUID PRIMARY KEY,
    nome              VARCHAR(120) NOT NULL,
    foto_url          VARCHAR(300),
    -- texto livre: "4 porções", "2 litros", "12 unidades"
    rendimento        VARCHAR(60),
    tempo_preparo_min INT          CHECK (tempo_preparo_min >= 0),
    ingredientes      TEXT,
    modo_preparo      TEXT,
    version           BIGINT       NOT NULL DEFAULT 0,
    criado_em         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uk_receita_nome ON receita (lower(nome));
