-- =====================================================================
-- Comandas (contas abertas): o cliente vai consumindo e paga no fim.
-- Itens lançados reservam o estoque dos produtos controlados; ao fechar,
-- a reserva vira baixa e é gerada uma venda vinculada à comanda.
-- Toda comanda pertence ao caixa aberto em que foi aberta; o caixa só
-- fecha depois que todas as suas comandas forem fechadas ou canceladas.
-- =====================================================================

CREATE SEQUENCE comanda_numero_seq;

CREATE TABLE comanda (
    id                  UUID PRIMARY KEY,
    numero              BIGINT        NOT NULL UNIQUE,
    caixa_id            UUID          NOT NULL REFERENCES caixa (id),
    cliente_nome        VARCHAR(80)   NOT NULL,
    local               VARCHAR(80),
    observacao          VARCHAR(500),
    status              VARCHAR(10)   NOT NULL CHECK (status IN ('ABERTA', 'FECHADA', 'CANCELADA')),
    total               NUMERIC(14,2) NOT NULL DEFAULT 0,
    venda_id            UUID          UNIQUE,
    motivo_cancelamento VARCHAR(500),
    fechada_em          TIMESTAMPTZ,
    cancelada_em        TIMESTAMPTZ,
    version             BIGINT        NOT NULL DEFAULT 0,
    criado_em           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em       TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_comanda_status ON comanda (status, criado_em);
CREATE INDEX ix_comanda_caixa ON comanda (caixa_id, status);

-- Preço congelado no lançamento; mesmo produto/preço/observação somam na mesma linha.
CREATE TABLE comanda_item (
    id               UUID PRIMARY KEY,
    comanda_id       UUID          NOT NULL REFERENCES comanda (id),
    produto_id       UUID          NOT NULL REFERENCES produto (id),
    produto_nome     VARCHAR(120)  NOT NULL,
    quantidade       NUMERIC(15,3) NOT NULL CHECK (quantidade > 0),
    preco_unitario   NUMERIC(14,2) NOT NULL,
    total            NUMERIC(14,2) NOT NULL,
    observacao       VARCHAR(200),
    controla_estoque BOOLEAN       NOT NULL,
    version          BIGINT        NOT NULL DEFAULT 0,
    criado_em        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_comanda_item_comanda ON comanda_item (comanda_id);

ALTER TABLE venda ADD COLUMN comanda_id UUID UNIQUE REFERENCES comanda (id);
