-- =====================================================================
-- Etapa 7 — Despesas operacionais e dashboard/relatórios.
-- =====================================================================

CREATE TABLE despesa (
    id            UUID PRIMARY KEY,
    descricao     VARCHAR(200)  NOT NULL,
    categoria     VARCHAR(20)   NOT NULL CHECK (categoria IN
                      ('AGUA', 'LUZ', 'GAS', 'ALUGUEL', 'MANUTENCAO', 'LIMPEZA', 'FUNCIONARIOS', 'IMPOSTOS', 'OUTROS')),
    valor         NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    data          DATE          NOT NULL,
    fornecedor_id UUID          REFERENCES fornecedor (id),
    observacao    VARCHAR(500),
    version       BIGINT        NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_despesa_data ON despesa (data DESC);

-- Dados de demonstração no dashboard e relatórios (para apresentações). Desligue para ver os dados reais.
INSERT INTO configuracao (chave, valor, descricao) VALUES
    ('dados_demonstracao', 'true', 'Mostra dados de demonstração no dashboard e nos relatórios');
