-- =====================================================================
-- Etapa 4 — Vendas (PDV) e controle de caixa.
-- =====================================================================

-- Pratos preparados (porções, lanches) não têm controle de estoque: a venda registra
-- faturamento e custo, sem movimentar estoque.
ALTER TABLE produto ADD COLUMN controla_estoque BOOLEAN NOT NULL DEFAULT TRUE;

-- ------------------------------------------------------------------ caixa

CREATE TABLE caixa (
    id                    UUID PRIMARY KEY,
    status                VARCHAR(10)   NOT NULL CHECK (status IN ('ABERTO', 'FECHADO')),
    aberto_em             TIMESTAMPTZ   NOT NULL,
    saldo_inicial         NUMERIC(14,2) NOT NULL CHECK (saldo_inicial >= 0),
    observacao_abertura   VARCHAR(500),
    -- preenchidos no fechamento (congelam o resultado conferido)
    fechado_em            TIMESTAMPTZ,
    total_vendas          NUMERIC(14,2),
    quantidade_vendas     INT,
    total_dinheiro        NUMERIC(14,2),
    total_pix             NUMERIC(14,2),
    total_cartao_debito   NUMERIC(14,2),
    total_cartao_credito  NUMERIC(14,2),
    total_outros          NUMERIC(14,2),
    total_suprimentos     NUMERIC(14,2),
    total_retiradas       NUMERIC(14,2),
    saldo_esperado        NUMERIC(14,2),
    saldo_contado         NUMERIC(14,2) CHECK (saldo_contado >= 0),
    diferenca             NUMERIC(14,2),
    observacao_fechamento VARCHAR(500),
    version               BIGINT        NOT NULL DEFAULT 0,
    criado_em             TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em         TIMESTAMPTZ   NOT NULL DEFAULT now()
);
-- No máximo um caixa aberto por vez.
CREATE UNIQUE INDEX uk_caixa_aberto ON caixa (status) WHERE status = 'ABERTO';
CREATE INDEX ix_caixa_aberto_em ON caixa (aberto_em DESC);

-- Suprimento (entrada de dinheiro, ex.: troco) e retirada (sangria) manuais.
CREATE TABLE movimentacao_caixa (
    id        UUID PRIMARY KEY,
    caixa_id  UUID          NOT NULL REFERENCES caixa (id),
    tipo      VARCHAR(12)   NOT NULL CHECK (tipo IN ('SUPRIMENTO', 'RETIRADA')),
    valor     NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    motivo    VARCHAR(300)  NOT NULL,
    data_hora TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_movimentacao_caixa ON movimentacao_caixa (caixa_id, data_hora);

-- ------------------------------------------------------------------ vendas

CREATE SEQUENCE venda_numero_seq;

CREATE TABLE venda (
    id                  UUID PRIMARY KEY,
    numero              BIGINT        NOT NULL UNIQUE,
    -- gerada pelo PDV a cada carrinho: reenviar a mesma venda não a duplica
    chave_idempotencia  UUID          NOT NULL UNIQUE,
    caixa_id            UUID          NOT NULL REFERENCES caixa (id),
    data_hora           TIMESTAMPTZ   NOT NULL,
    subtotal            NUMERIC(14,2) NOT NULL CHECK (subtotal >= 0),
    desconto            NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (desconto >= 0),
    total               NUMERIC(14,2) NOT NULL CHECK (total >= 0),
    -- custo dos produtos no momento da venda e lucro bruto estimado (total − custo)
    custo_total         NUMERIC(14,2) NOT NULL,
    lucro_bruto         NUMERIC(14,2) NOT NULL,
    forma_pagamento     VARCHAR(20)   NOT NULL CHECK (forma_pagamento IN
                            ('DINHEIRO', 'PIX', 'CARTAO_DEBITO', 'CARTAO_CREDITO', 'OUTROS')),
    valor_recebido      NUMERIC(14,2),
    troco               NUMERIC(14,2),
    observacao          VARCHAR(500),
    status              VARCHAR(12)   NOT NULL CHECK (status IN ('CONCLUIDA', 'CANCELADA')),
    motivo_cancelamento VARCHAR(500),
    cancelada_em        TIMESTAMPTZ,
    version             BIGINT        NOT NULL DEFAULT 0,
    criado_em           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_venda_total CHECK (total = subtotal - desconto)
);
CREATE INDEX ix_venda_data ON venda (data_hora DESC);
CREATE INDEX ix_venda_caixa ON venda (caixa_id);

-- Itens com preço e custo congelados no momento da venda (alterações futuras não mudam o histórico).
CREATE TABLE venda_item (
    id               UUID PRIMARY KEY,
    venda_id         UUID          NOT NULL REFERENCES venda (id),
    ordem            INT           NOT NULL,
    produto_id       UUID          NOT NULL REFERENCES produto (id),
    produto_nome     VARCHAR(120)  NOT NULL,
    quantidade       NUMERIC(15,3) NOT NULL CHECK (quantidade > 0),
    preco_unitario   NUMERIC(14,2) NOT NULL CHECK (preco_unitario >= 0),
    custo_unitario   NUMERIC(18,6) NOT NULL CHECK (custo_unitario >= 0),
    total            NUMERIC(14,2) NOT NULL,
    custo_total      NUMERIC(14,2) NOT NULL,
    controla_estoque BOOLEAN       NOT NULL,
    version          BIGINT        NOT NULL DEFAULT 0,
    criado_em        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uk_venda_item_ordem UNIQUE (venda_id, ordem)
);
CREATE INDEX ix_venda_item_produto ON venda_item (produto_id);
