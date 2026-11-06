# Arquitetura

## Visão geral

```
Funcionário → Flutter "admin" (Web/APK) ──┐  /api/admin/**  (JWT)
                                          ├──► Spring Boot (Java 21) ──► PostgreSQL
Cliente (QR) → Flutter Web "cardapio" ────┘  /api/public/** (aberto)
```

Toda regra de negócio fica no backend. O Flutter exibe dados, valida formato e chama a API.

## Backend — monólito modular

Pacote base `br.com.bar.gestao`. Cada módulo de negócio segue a mesma organização:

```
<modulo>/
  api/            controllers REST e DTOs (records)
  application/    serviços com as regras de negócio e transações
  domain/         entidades JPA e repositórios
```

| Módulo | Responsabilidade |
|---|---|
| `shared` | entidade base, erros padronizados (RFC 7807), segurança/JWT, OpenAPI, armazenamento de imagens |
| `auth` | usuário administrativo fixo e login |
| `configuracao` | parâmetros chave/valor (nome do bar, cardápio aberto, estoque negativo) |
| `catalogo` | categorias, unidades de medida, conversões, produtos e embalagens |
| `fornecedor` | cadastro de fornecedores |
| `receita` | receitas para consulta (ingredientes e modo de preparo em HTML limpo), independentes do resto |
| `estoque` | saldo, movimentações (histórico imutável), entradas/saídas/ajustes, inventário e consultas de posição |

Regras de acoplamento:

- Módulos se comunicam pelos **serviços** (`application`), nunca pelos repositórios de outro módulo.
- Outros módulos leem o catálogo por `ProdutoConsultaService` (fachada só de leitura, sem dependências),
  evitando ciclos: `catalogo → estoque` (criação do saldo) e `estoque → ProdutoConsultaService`.
- Consultas de relatório que cruzam várias tabelas usam SQL direto (`JdbcClient`) em serviços de leitura.
- Referências entre módulos usam **ID** (ex.: `produto.fornecedor_principal_id`), não associações JPA.
- O saldo de estoque só é alterado por `EstoqueService`.

## Erros da API

Todas as respostas de erro seguem `application/problem+json` com um `codigo` estável:

```json
{ "status": 422, "codigo": "PRECO_VENDA_OBRIGATORIO", "detail": "Informe o preço de venda...", "timestamp": "..." }
```

| HTTP | Uso |
|---|---|
| 400 | `DADOS_INVALIDOS` (inclui `campos`: campo → mensagem), `CORPO_INVALIDO` |
| 401 | `NAO_AUTENTICADO` |
| 404 | `NAO_ENCONTRADO` |
| 409 | `CONFLITO_CONCORRENCIA`, `VIOLACAO_INTEGRIDADE` |
| 422 | regras de negócio (`codigo` específico) |

## Frontend

```
frontend/
  packages/core/   ApiClient (Dio + JWT + erros), PageResponse, tema, formatadores, widgets comuns
  apps/admin/lib/
    app/           roteador (go_router + guarda de login), menu, shell responsivo
    features/<f>/  modelo + repositório + providers (Riverpod) + páginas
```

O painel usa menu lateral fixo (≥ 1100 px), recolhido em ícones (≥ 700 px) ou gaveta (celular).
