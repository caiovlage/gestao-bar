-- =====================================================================
-- Etapa 6 — Pedidos do cardápio digital.
-- O pedido é a solicitação do cliente; a venda só é gerada quando o
-- pagamento presencial é registrado. Status de preparo e financeiro são
-- independentes (ex.: ENTREGUE + PENDENTE = entregue aguardando pagamento).
-- =====================================================================

CREATE SEQUENCE pedido_numero_seq;

CREATE TABLE pedido (
    id                  UUID PRIMARY KEY,
    numero              BIGINT        NOT NULL UNIQUE,
    -- gerada pelo cardápio: reenviar o mesmo pedido não o duplica
    chave_idempotencia  UUID          NOT NULL UNIQUE,
    cliente_nome        VARCHAR(80)   NOT NULL,
    local               VARCHAR(80)   NOT NULL,
    observacao          VARCHAR(500),
    status_preparo      VARCHAR(15)   NOT NULL CHECK (status_preparo IN
                            ('RECEBIDO', 'ACEITO', 'EM_PREPARO', 'PRONTO', 'ENTREGUE', 'CANCELADO')),
    status_financeiro   VARCHAR(10)   NOT NULL CHECK (status_financeiro IN ('PENDENTE', 'PAGO', 'CANCELADO')),
    total               NUMERIC(14,2) NOT NULL,
    -- estoque reservado no aceite (liberado ao cancelar ou convertido em baixa no pagamento)
    estoque_reservado   BOOLEAN       NOT NULL DEFAULT FALSE,
    motivo_cancelamento VARCHAR(500),
    venda_id            UUID          UNIQUE,
    ip_origem           VARCHAR(64),
    aceito_em           TIMESTAMPTZ,
    pronto_em           TIMESTAMPTZ,
    entregue_em         TIMESTAMPTZ,
    pago_em             TIMESTAMPTZ,
    cancelado_em        TIMESTAMPTZ,
    version             BIGINT        NOT NULL DEFAULT 0,
    criado_em           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em       TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_pedido_status ON pedido (status_preparo, status_financeiro);
CREATE INDEX ix_pedido_criado ON pedido (criado_em DESC);

-- Itens com o preço do momento do pedido (o que o cliente viu no cardápio).
CREATE TABLE pedido_item (
    id             UUID PRIMARY KEY,
    pedido_id      UUID          NOT NULL REFERENCES pedido (id),
    ordem          INT           NOT NULL,
    produto_id     UUID          NOT NULL REFERENCES produto (id),
    produto_nome   VARCHAR(120)  NOT NULL,
    quantidade     INT           NOT NULL CHECK (quantidade BETWEEN 1 AND 50),
    preco_unitario NUMERIC(14,2) NOT NULL,
    total          NUMERIC(14,2) NOT NULL,
    observacao     VARCHAR(200),
    version        BIGINT        NOT NULL DEFAULT 0,
    criado_em      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_pedido_item_pedido ON pedido_item (pedido_id);

-- A venda gerada por um pedido referencia o pedido de origem; no máximo uma venda por pedido.
ALTER TABLE venda ADD COLUMN pedido_id UUID UNIQUE REFERENCES pedido (id);
