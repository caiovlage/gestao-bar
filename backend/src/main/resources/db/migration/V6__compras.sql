-- =====================================================================
-- Etapa 5 — Compras: listas de compras (rascunho), recebimento com entrada
-- no estoque, custo médio ponderado e histórico de preços de aquisição.
-- =====================================================================

CREATE SEQUENCE compra_numero_seq;

CREATE TABLE compra (
    id            UUID PRIMARY KEY,
    numero        BIGINT        NOT NULL UNIQUE,
    fornecedor_id UUID          REFERENCES fornecedor (id),
    -- RASCUNHO = lista de compras editável; RECEBIDA = mercadoria entrou no estoque
    status        VARCHAR(12)   NOT NULL CHECK (status IN ('RASCUNHO', 'RECEBIDA', 'CANCELADA')),
    observacao    VARCHAR(500),
    total         NUMERIC(14,2) NOT NULL DEFAULT 0,
    recebida_em   TIMESTAMPTZ,
    cancelada_em  TIMESTAMPTZ,
    version       BIGINT        NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_compra_status ON compra (status, criado_em DESC);

CREATE TABLE compra_item (
    id                     UUID PRIMARY KEY,
    compra_id              UUID          NOT NULL REFERENCES compra (id) ON DELETE CASCADE,
    ordem                  INT           NOT NULL,
    produto_id             UUID          NOT NULL REFERENCES produto (id),
    produto_nome           VARCHAR(120)  NOT NULL,
    -- quantidade na unidade de compra (ex.: 3 caixas) e a cópia da unidade/embalagem usada
    quantidade             NUMERIC(15,3) NOT NULL CHECK (quantidade > 0),
    unidade_id             UUID,
    embalagem_id           UUID,
    unidade_compra         VARCHAR(80)   NOT NULL,
    quantidade_estoque     NUMERIC(15,3) NOT NULL CHECK (quantidade_estoque > 0),
    -- preço por unidade de compra (ex.: R$ 42,00 a caixa)
    custo_unitario         NUMERIC(14,4) NOT NULL CHECK (custo_unitario >= 0),
    custo_total            NUMERIC(14,2) NOT NULL,
    version                BIGINT        NOT NULL DEFAULT 0,
    criado_em              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em          TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_compra_item_compra ON compra_item (compra_id);
CREATE INDEX ix_compra_item_produto ON compra_item (produto_id);

-- Preço de aquisição de cada recebimento (por unidade de estoque) e o efeito no custo médio.
CREATE TABLE historico_custo (
    id                   UUID PRIMARY KEY,
    produto_id           UUID          NOT NULL REFERENCES produto (id),
    fornecedor_id        UUID          REFERENCES fornecedor (id),
    compra_id            UUID          NOT NULL REFERENCES compra (id),
    data_hora            TIMESTAMPTZ   NOT NULL,
    quantidade           NUMERIC(15,3) NOT NULL,
    custo_unitario       NUMERIC(18,6) NOT NULL,
    custo_medio_anterior NUMERIC(18,6) NOT NULL,
    custo_medio_novo     NUMERIC(18,6) NOT NULL
);
CREATE INDEX ix_historico_custo_produto ON historico_custo (produto_id, data_hora DESC);
