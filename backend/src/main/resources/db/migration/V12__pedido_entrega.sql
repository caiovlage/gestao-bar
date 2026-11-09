-- Pedidos para entrega no condomínio: o cliente informa bloco e apartamento.
-- "local" continua preenchido com o texto completo (ex.: "Bloco B · Apto 101") para exibição.
ALTER TABLE pedido ADD COLUMN bloco VARCHAR(20);
ALTER TABLE pedido ADD COLUMN apartamento VARCHAR(20);
