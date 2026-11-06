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

## Situação atual — Etapa 1 (Fundação) concluída

- Autenticação com usuário fixo (variáveis de ambiente) e JWT
- Categorias, unidades de medida (com conversões), fornecedores e produtos (com embalagens e imagem)
- Painel com login, menu lateral responsivo e telas de Produtos, Categorias, Fornecedores e Configurações

Próximas etapas: 2 Estoque · 3 Receitas · 4 Vendas e Caixa · 5 Compras · 6 Pedidos web · 7 BI.

## Instalar ou atualizar no servidor (Oracle Linux)

```bash
git clone https://github.com/caiovlage/gestao-bar.git ~/gestao-bar
cd ~/gestao-bar && ./deploy.sh
```

O mesmo `./deploy.sh` atualiza tudo depois (código, banco, painel e backend). Detalhes, opções e
solução de problemas em [docs/instalacao.md](docs/instalacao.md).
