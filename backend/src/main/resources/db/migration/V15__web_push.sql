-- =====================================================================
-- Notificações push (Web Push) de novos pedidos para os aparelhos que
-- aceitarem receber. As chaves VAPID identificam este servidor junto aos
-- serviços de push dos navegadores e são geradas na primeira execução.
-- =====================================================================

CREATE TABLE push_vapid (
    id            SMALLINT     PRIMARY KEY CHECK (id = 1),
    chave_publica VARCHAR(100) NOT NULL,   -- ponto P-256 não comprimido, base64url
    chave_privada VARCHAR(100) NOT NULL,   -- escalar P-256, base64url
    criado_em     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE push_inscricao (
    id            UUID          PRIMARY KEY,
    endpoint      VARCHAR(1000) NOT NULL UNIQUE,
    p256dh        VARCHAR(200)  NOT NULL,
    auth          VARCHAR(100)  NOT NULL,
    dispositivo   VARCHAR(120),
    usuario       VARCHAR(60),
    falhas        INT           NOT NULL DEFAULT 0,
    ultimo_envio  TIMESTAMPTZ,
    criado_em     TIMESTAMPTZ   NOT NULL DEFAULT now()
);
