# Gestão do Bar

Sistema de gestão para bar: produtos, estoque, receitas, vendas (PDV), caixa, compras,
fornecedores, despesas, cardápio digital com pedidos via QR Code e indicadores gerenciais.

| Parte | Tecnologia |
|---|---|
| Backend | Java 21 · Spring Boot 4.1 · Spring Security (JWT) · JPA/Hibernate 7 · PostgreSQL 16 · Flyway · OpenAPI |
| Frontend | Flutter (Web + Android) · Riverpod 3 · Dio · go_router |
| Execução | Docker Compose |

## Estrutura

```
backend/            API REST (monólito modular)
frontend/
  packages/core/    código compartilhado (cliente HTTP, tema, widgets)
  apps/admin/       painel administrativo + PDV
infra/nginx/        proxy reverso para produção
docs/               instalação, arquitetura e decisões
```

## Situação atual

| Etapa | Situação |
|---|---|
| 1. Fundação — login, produtos, categorias, unidades, fornecedores | ✅ concluída |
| 2. Estoque — movimentações, entradas, perdas, ajustes, inventário | ✅ concluída |
| 3. Receitas — cadastro e consulta, colando a formatação de sites | ✅ concluída |
| 4. Vendas e Caixa — PDV, desconto, troco, cancelamento, abertura e fechamento de caixa | ✅ concluída |
| 5. Compras — sugestões, listas (PDF/Excel), recebimento e custo médio | ✅ concluída |
| 6. Pedidos web — cardápio por QR Code, pedido pelo celular, kanban, pagamento gerando venda | ✅ concluída |
| 7. BI — dashboard, relatórios, despesas, dados de demonstração | ✅ concluída |

## Instalar ou atualizar no servidor (Oracle Linux)

```bash
git clone https://github.com/caiovlage/gestao-bar.git ~/gestao-bar
cd ~/gestao-bar && ./deploy.sh
```

O mesmo `./deploy.sh` atualiza tudo depois (código, banco, painel e backend). Detalhes, opções e
solução de problemas em [docs/instalacao.md](docs/instalacao.md).
