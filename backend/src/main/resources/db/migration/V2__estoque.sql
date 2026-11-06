-- =====================================================================
-- Etapa 2 — Estoque: movimentações (histórico imutável) e inventários.
-- Toda alteração de saldo em "estoque" gera exatamente uma linha em
-- movimentacao_estoque, na mesma transação.
-- =====================================================================

CREATE TABLE movimentacao_estoque (
    id                   UUID PRIMARY KEY,
    produto_id           UUID          NOT NULL REFERENCES produto (id),
    tipo                 VARCHAR(30)   NOT NULL CHECK (tipo IN (
                             'ENTRADA_MANUAL', 'ENTRADA_COMPRA', 'ESTORNO_VENDA',
                             'SAIDA_VENDA', 'CONSUMO_RECEITA', 'CONSUMO_INTERNO', 'PERDA',
                             'DEVOLUCAO_FORNECEDOR', 'AJUSTE_INVENTARIO')),
    -- positiva = entrada, negativa = saída (sempre na unidade de estoque do produto)
    quantidade           NUMERIC(15,3) NOT NULL CHECK (quantidade <> 0),
    saldo_anterior       NUMERIC(15,3) NOT NULL,
    saldo_posterior      NUMERIC(15,3) NOT NULL,
    -- custo unitário do produto no momento da movimentação (valoriza perdas, consumo etc.)
    custo_unitario       NUMERIC(18,6) NOT NULL DEFAULT 0,
    -- como o operador informou, quando diferente da unidade de estoque (ex.: "2 × Caixa 12")
    quantidade_informada VARCHAR(80),
    origem_tipo          VARCHAR(30)   NOT NULL CHECK (origem_tipo IN (
                             'MANUAL', 'AJUSTE_AVULSO', 'INVENTARIO', 'COMPRA', 'VENDA', 'PEDIDO')),
    origem_id            UUID,
    observacao           VARCHAR(500),
    data_hora            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_movimentacao_saldo CHECK (saldo_posterior = saldo_anterior + quantidade)
);
CREATE INDEX ix_movimentacao_produto_data ON movimentacao_estoque (produto_id, data_hora DESC);
CREATE INDEX ix_movimentacao_data ON movimentacao_estoque (data_hora DESC);
CREATE INDEX ix_movimentacao_origem ON movimentacao_estoque (origem_tipo, origem_id);

CREATE TABLE inventario (
    id            UUID PRIMARY KEY,
    descricao     VARCHAR(120) NOT NULL,
    categoria_id  UUID         REFERENCES categoria (id),
    status        VARCHAR(20)  NOT NULL CHECK (status IN ('ABERTO', 'CONCLUIDO', 'CANCELADO')),
    observacao    VARCHAR(500),
    concluido_em  TIMESTAMPTZ,
    cancelado_em  TIMESTAMPTZ,
    version       BIGINT       NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ  NOT NULL DEFAULT now()
);
-- No máximo um inventário em andamento por vez.
CREATE UNIQUE INDEX uk_inventario_aberto ON inventario (status) WHERE status = 'ABERTO';
CREATE INDEX ix_inventario_criado ON inventario (criado_em DESC);

CREATE TABLE inventario_item (
    id                 UUID PRIMARY KEY,
    inventario_id      UUID          NOT NULL REFERENCES inventario (id),
    produto_id         UUID          NOT NULL REFERENCES produto (id),
    quantidade_contada NUMERIC(15,3) CHECK (quantidade_contada >= 0),
    -- preenchidos na conclusão: saldo do sistema naquele instante e o ajuste gerado
    quantidade_sistema NUMERIC(15,3),
    diferenca          NUMERIC(15,3),
    movimentacao_id    UUID          REFERENCES movimentacao_estoque (id),
    version            BIGINT        NOT NULL DEFAULT 0,
    criado_em          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uk_inventario_item UNIQUE (inventario_id, produto_id)
);
