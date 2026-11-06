-- Código do produto lido por câmera ou leitor USB: códigos de barras (EAN-13 = 13 dígitos)
-- cabem em 30 caracteres, mas QR Codes podem ser bem mais longos (ex.: URLs).
ALTER TABLE produto ALTER COLUMN codigo_interno TYPE VARCHAR(100);
