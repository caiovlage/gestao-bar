-- =====================================================================
-- Etapa 1 — Fundação: autenticação, configurações, unidades, categorias,
-- fornecedores, produtos, embalagens e saldo de estoque.
-- Convenções: UUID como PK, TIMESTAMPTZ (UTC), dinheiro NUMERIC(14,2),
-- custo unitário NUMERIC(18,6), quantidades NUMERIC(15,3).
-- =====================================================================

CREATE TABLE usuario (
    id            UUID PRIMARY KEY,
    login         VARCHAR(60)  NOT NULL UNIQUE,
    senha_hash    VARCHAR(100) NOT NULL,
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
    version       BIGINT       NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE configuracao (
    chave         VARCHAR(60)  PRIMARY KEY,
    valor         VARCHAR(500) NOT NULL,
    descricao     VARCHAR(200),
    atualizado_em TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE unidade_medida (
    id            UUID PRIMARY KEY,
    sigla         VARCHAR(10)   NOT NULL,
    nome          VARCHAR(40)   NOT NULL,
    grandeza      VARCHAR(20)   NOT NULL CHECK (grandeza IN ('MASSA', 'VOLUME', 'UNIDADE', 'EMBALAGEM')),
    -- fator para a unidade base da grandeza (g, ml, un). Embalagens não têm fator fixo:
    -- a conversão depende do produto (ver produto_embalagem).
    fator_base    NUMERIC(15,6),
    version       BIGINT        NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_unidade_fator CHECK ((grandeza = 'EMBALAGEM') = (fator_base IS NULL)),
    CONSTRAINT ck_unidade_fator_positivo CHECK (fator_base IS NULL OR fator_base > 0)
);
CREATE UNIQUE INDEX uk_unidade_sigla ON unidade_medida (lower(sigla));

CREATE TABLE categoria (
    id              UUID PRIMARY KEY,
    nome            VARCHAR(60)  NOT NULL,
    ordem           INT          NOT NULL DEFAULT 0,
    exibir_cardapio BOOLEAN      NOT NULL DEFAULT TRUE,
    ativo           BOOLEAN      NOT NULL DEFAULT TRUE,
    version         BIGINT       NOT NULL DEFAULT 0,
    criado_em       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atualizado_em   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uk_categoria_nome ON categoria (lower(nome));

CREATE TABLE fornecedor (
    id            UUID PRIMARY KEY,
    nome          VARCHAR(120)  NOT NULL,
    nome_fantasia VARCHAR(120),
    cnpj          VARCHAR(14),
    telefone      VARCHAR(20),
    email         VARCHAR(120),
    endereco      VARCHAR(250),
    observacoes   VARCHAR(1000),
    ativo         BOOLEAN       NOT NULL DEFAULT TRUE,
    version       BIGINT        NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uk_fornecedor_cnpj ON fornecedor (cnpj) WHERE cnpj IS NOT NULL;
CREATE INDEX ix_fornecedor_nome ON fornecedor (lower(nome));

CREATE TABLE produto (
    id                      UUID PRIMARY KEY,
    nome                    VARCHAR(120)  NOT NULL,
    descricao               VARCHAR(1000),
    categoria_id            UUID          REFERENCES categoria (id),
    tipo                    VARCHAR(20)   NOT NULL CHECK (tipo IN ('REVENDA', 'INGREDIENTE', 'AMBOS')),
    unidade_estoque_id      UUID          NOT NULL REFERENCES unidade_medida (id),
    -- custo de aquisição por unidade de estoque (custo médio ponderado a partir da Etapa 5)
    custo_medio             NUMERIC(18,6) NOT NULL DEFAULT 0 CHECK (custo_medio >= 0),
    preco_venda             NUMERIC(14,2) CHECK (preco_venda >= 0),
    estoque_minimo          NUMERIC(15,3) NOT NULL DEFAULT 0 CHECK (estoque_minimo >= 0),
    fornecedor_principal_id UUID          REFERENCES fornecedor (id),
    codigo_interno          VARCHAR(30),
    imagem_url              VARCHAR(300),
    vende_no_cardapio       BOOLEAN       NOT NULL DEFAULT FALSE,
    ativo                   BOOLEAN       NOT NULL DEFAULT TRUE,
    version                 BIGINT        NOT NULL DEFAULT 0,
    criado_em               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em           TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uk_produto_codigo_interno ON produto (lower(codigo_interno)) WHERE codigo_interno IS NOT NULL;
CREATE INDEX ix_produto_nome ON produto (lower(nome));
CREATE INDEX ix_produto_categoria ON produto (categoria_id);

-- Embalagens de compra específicas do produto. Ex.: "Caixa 12" (cx) = 12 un; "Pacote 2 kg" (pct) = 2000 g.
CREATE TABLE produto_embalagem (
    id            UUID PRIMARY KEY,
    produto_id    UUID          NOT NULL REFERENCES produto (id) ON DELETE CASCADE,
    unidade_id    UUID          NOT NULL REFERENCES unidade_medida (id),
    descricao     VARCHAR(60)   NOT NULL,
    fator         NUMERIC(15,3) NOT NULL CHECK (fator > 0),
    version       BIGINT        NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    atualizado_em TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX ix_produto_embalagem_produto ON produto_embalagem (produto_id);

-- Saldo de estoque (na unidade de estoque do produto). Só é alterado pelo módulo de estoque,
-- sempre acompanhado de uma movimentação (Etapa 2).
CREATE TABLE estoque (
    produto_id           UUID          PRIMARY KEY REFERENCES produto (id) ON DELETE CASCADE,
    quantidade           NUMERIC(15,3) NOT NULL DEFAULT 0,
    quantidade_reservada NUMERIC(15,3) NOT NULL DEFAULT 0 CHECK (quantidade_reservada >= 0),
    version              BIGINT        NOT NULL DEFAULT 0,
    atualizado_em        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ------------------------------- Dados iniciais -------------------------------

INSERT INTO unidade_medida (id, sigla, nome, grandeza, fator_base) VALUES
    (gen_random_uuid(), 'un',  'Unidade',    'UNIDADE',   1),
    (gen_random_uuid(), 'g',   'Grama',      'MASSA',     1),
    (gen_random_uuid(), 'kg',  'Quilograma', 'MASSA',     1000),
    (gen_random_uuid(), 'ml',  'Mililitro',  'VOLUME',    1),
    (gen_random_uuid(), 'L',   'Litro',      'VOLUME',    1000),
    (gen_random_uuid(), 'pct', 'Pacote',     'EMBALAGEM', NULL),
    (gen_random_uuid(), 'cx',  'Caixa',      'EMBALAGEM', NULL);

INSERT INTO categoria (id, nome, ordem, exibir_cardapio) VALUES
    (gen_random_uuid(), 'Bebidas',       10, TRUE),
    (gen_random_uuid(), 'Cervejas',      20, TRUE),
    (gen_random_uuid(), 'Refrigerantes', 30, TRUE),
    (gen_random_uuid(), 'Porções',       40, TRUE),
    (gen_random_uuid(), 'Lanches',       50, TRUE),
    (gen_random_uuid(), 'Sobremesas',    60, TRUE),
    (gen_random_uuid(), 'Ingredientes',  70, FALSE),
    (gen_random_uuid(), 'Outros',        80, TRUE);

INSERT INTO configuracao (chave, valor, descricao) VALUES
    ('nome_bar',                  'Meu Bar', 'Nome exibido no painel e no cardápio'),
    ('cardapio_aberto',           'true',    'Se o cardápio público aceita novos pedidos'),
    ('permitir_estoque_negativo', 'false',   'Permite vendas/baixas que deixem o estoque negativo');
