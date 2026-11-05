# Decisões técnicas e de negócio

Registro das decisões tomadas durante a implementação (validar com o responsável pelo negócio quando indicado).

## Etapa 1 — Fundação

| # | Decisão | Motivo |
|---|---|---|
| 1 | **Spring Boot 4.1.2** (em vez de 3.x previsto na especificação) | Solicitado: versão mais recente. Implica Jackson 3, Hibernate 7 e Spring Security 7. |
| 2 | Estoque sempre na **unidade base** (un, g ou ml) | Evita arredondamentos e conversões em cascata; compras em kg/L/caixa são convertidas na entrada. |
| 3 | Conversões **kg↔g e L↔ml automáticas**; **caixa/pacote definidos por produto** (`produto_embalagem`) | "1 caixa" vale 12 un para uma cerveja e 6 un para outra; o fator não pode ser global. |
| 4 | Toda conversão passa por `ConversaoUnidadeService` | Requisito de centralizar conversões. |
| 5 | Produto do tipo **Ingrediente** não tem preço de venda nem aparece no cardápio | Coerência: ingrediente puro não é vendido. |
| 6 | **Exclusão** de produto/categoria só sem vínculos; caso contrário, **inativar** | Requisito de preservar histórico. Garantido por FKs restritivas no banco. |
| 7 | `custo_medio` editável manualmente nesta etapa; a partir da Etapa 5 será recalculado por **custo médio ponderado** nas compras | Ainda não há módulo de compras. |
| 8 | Unidade de estoque não pode mudar se houver saldo | Evita reinterpretar quantidades existentes. |
| 9 | Senha do admin vem de `ADMIN_PASSWORD` e é guardada como hash BCrypt; token JWT com validade de 12 h, sem refresh | Requisito de autenticação simples; 12 h cobre um turno. |
| 10 | Imagens em disco local (volume Docker), validadas pela assinatura do arquivo, nomes UUID | Simples; pode migrar para armazenamento de objetos no futuro. |
| 11 | Frontend sem geração de código (`freezed`/`riverpod_generator`); modelos `fromJson` escritos à mão | Menos etapas de build; os modelos são pequenos. |

## Próximas etapas — sugestões a validar

- **Reserva de estoque** de pedidos web no momento do **aceite** (não no recebimento), liberada ao cancelar.
- **Venda exige caixa aberto**, tanto no PDV quanto na finalização de pedidos.
- **Bloqueio pessimista** por produto (`SELECT … FOR UPDATE` ordenado por id) nas baixas de estoque.
