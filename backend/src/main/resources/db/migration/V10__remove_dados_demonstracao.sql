-- Dashboard, relatórios e cardápio passam a mostrar sempre os dados reais:
-- a opção de dados de demonstração foi removida.
DELETE FROM configuracao WHERE chave = 'dados_demonstracao';
