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

## Etapa 2 — Estoque

| # | Decisão | Motivo |
|---|---|---|
| 12 | Saldo alterado **somente** por `EstoqueService`, sempre com uma linha em `movimentacao_estoque` na mesma transação; o banco garante `saldo_posterior = saldo_anterior + quantidade` | Auditoria completa: o saldo pode ser reconstruído pelo histórico. Movimentações são imutáveis. |
| 13 | **Bloqueio pessimista** (`SELECT … FOR UPDATE`) dos saldos envolvidos, sempre em ordem crescente de `produto_id` | Operações simultâneas nunca deixam o saldo errado nem negativo; a ordem fixa evita deadlocks. Testado com 8 saídas simultâneas. |
| 14 | Saídas validam o saldo **disponível** (`quantidade − reservada`); estoque negativo bloqueado salvo configuração | Prepara a reserva dos pedidos web (Etapa 6). |
| 15 | Tipos manuais: entrada, consumo interno, **perda (motivo obrigatório)** e **devolução ao fornecedor** (saída). Venda, consumo de receita, compra e estorno são exclusivos do sistema | "Devolução" da especificação interpretada como devolução ao fornecedor; estorno de venda é tipo próprio (Etapa 4). |
| 16 | Entrada manual **não altera o custo** do produto; registra o custo vigente na movimentação | O custo médio ponderado será recalculado pelas compras (Etapa 5). |
| 17 | Quantidade pode ser informada em unidade compatível (kg para produto em g) ou embalagem (caixa), convertida no backend; a forma informada fica registrada ("2 × Caixa 12") | Facilita o uso e mantém a auditoria. |
| 18 | **Inventário**: um aberto por vez; contagem salva aos poucos; itens não contados são ignorados; a diferença é calculada contra o saldo **no momento da conclusão** | Vendas durante a contagem não se perdem; inventários parciais (por categoria) são possíveis. |
| 19 | **Ajuste avulso** de um produto (contagem rápida) gera o mesmo tipo de movimentação do inventário | Corrigir divergências sem abrir um inventário completo. |
| 20 | Unidade de estoque não pode mudar se o produto já tiver movimentações | O histórico está na unidade original. |
| 21 | Filtros por data usam o fuso do bar (`FUSO_HORARIO`, padrão `America/Sao_Paulo`); o banco guarda tudo em UTC | "Hoje" no bar não é o mesmo dia que em UTC após as 21h. |

## Etapa 3 — Receitas

| # | Decisão | Motivo |
|---|---|---|
| 22 | Receitas são **apenas para consulta**: nome, foto, rendimento (texto livre), tempo, ingredientes e modo de preparo. **Sem vínculo** com produtos, estoque, categorias ou custos | Pedido do responsável: cadastro simples para consulta rápida na cozinha. Consequência: a venda de pratos preparados **não baixa ingredientes automaticamente**; o estoque de ingredientes é controlado por movimentações (consumo interno, perdas) e inventários. O vínculo pode ser adicionado no futuro sem refazer as receitas. |
| 23 | **Ingredientes e modo de preparo aceitam texto colado de sites com a formatação**: editor visual no navegador (área editável nativa em iframe), guardado em HTML e **limpo no servidor** (jsoup), mantendo parágrafos, negrito, itálico, sublinhado, títulos e listas; removendo scripts, estilos, cores, fontes, imagens e links | Colar com formatação não é suportado pelos editores Flutter na Web (`flutter_quill`) e a API de área de transferência exige HTTPS. A limpeza garante segurança e leitura uniforme. No APK, a edição é em texto simples. |
| 24 | Tela de consulta com **letra ajustável** e layout em duas colunas (ingredientes ao lado do preparo) em telas largas | Leitura à distância na cozinha. |

## Cadastro de produto por código de barras / QR Code

| # | Decisão | Motivo |
|---|---|---|
| 25 | Botão **"Ler código"** na lista de produtos: código já cadastrado abre o produto; código novo abre o cadastro com o código preenchido. No formulário, o campo de código também tem o leitor | Pedido do responsável. |
| 26 | O código lido fica no campo existente **"código interno"**, ampliado de 30 para **100 caracteres** (QR Codes podem conter URLs) e único por produto (sem diferenciar maiúsculas) | Evita um campo novo; códigos de barras e códigos internos convivem no mesmo lugar. |
| 27 | Leitura pela **câmera** (pacote `mobile_scanner`) no APK e no navegador em **HTTPS/localhost**; pelo IP em HTTP o navegador bloqueia a câmera, então o leitor aceita **digitação ou leitor USB** (que "digita" o código e tecla Enter) | Regra de segurança dos navegadores; o leitor USB funciona em qualquer cenário. |

## Etapa 4 — Vendas e caixa

| # | Decisão | Motivo |
|---|---|---|
| 28 | Produto com opção **"Controlar estoque"**: desligada para pratos preparados, que só registram faturamento e **custo de preparo** (para lucro e margem), sem movimentar estoque; ficam fora da posição de estoque e dos inventários | Pedido do responsável: pratos sem controle de estoque, mas com custo para saber o lucro. |
| 29 | **Venda exige caixa aberto**; um caixa aberto por vez | O fechamento confere todas as vendas do turno. |
| 30 | A venda **congela nome, preço e custo** de cada item; lucro bruto = total (após desconto) − custo | Alterações futuras de preço/custo não mudam o histórico. |
| 31 | **Desconto** no total da venda, em valor **ou** percentual; **uma forma de pagamento** por venda; em dinheiro, valor recebido e troco | Rapidez no PDV. |
| 32 | **Idempotência**: cada carrinho tem uma chave única; reenviar a mesma venda (duplo clique, rede instável) devolve a venda já registrada | Evita vendas e baixas de estoque duplicadas. |
| 33 | **Cancelamento** com justificativa, **só enquanto o caixa da venda estiver aberto**; a venda fica no histórico como cancelada e o estoque é estornado | Caixa fechado e conferido não muda depois. |
| 34 | **Concorrência venda × fechamento**: a venda trava o caixa em modo compartilhado e o fechamento em modo exclusivo | Nenhuma venda entra num caixa cujos totais já foram apurados. |
| 35 | Fechamento: totais por forma de pagamento, suprimentos, retiradas e **dinheiro esperado na gaveta** (inicial + dinheiro + suprimentos − retiradas) comparado ao **valor contado**; retirada maior que o esperado é recusada | Conferência simples do turno. |
| 36 | **Comprovante interno** em texto (não fiscal), exibido na tela com opção de copiar | Impressão direta fica para depois (exige integração com impressora). |
| 37 | PDV em **tela cheia**, separado do painel; busca por nome e por **código (leitor USB + Enter adiciona ao carrinho)** | Operação rápida no balcão. |

## Etapa 5 — Compras

| # | Decisão | Motivo |
|---|---|---|
| 38 | **Sugestão de reposição** = estoque mínimo − saldo atual, para produtos ativos com controle de estoque; arredondada para cima na **maior embalagem** do produto (ex.: faltam 36 latas → 3 caixas de 12) | Exemplo da especificação; compra-se em embalagens fechadas. |
| 39 | Lista de compras = compra em **rascunho** (editável, exportável em PDF/Excel); o **recebimento** dá entrada no estoque e encerra a lista | Um único registro do pedido ao recebimento. |
| 40 | **Custo médio ponderado** no recebimento: (saldo × custo atual + quantidade × custo da compra) ÷ (saldo + quantidade); com saldo zerado, vale o custo da compra | Custo mais fiel que o último preço; base do lucro das vendas. |
| 41 | **Histórico de preços** por recebimento (custo por unidade de estoque, fornecedor, custo médio antes/depois), exibido no cadastro do produto | Acompanhar a variação dos fornecedores. |
| 42 | O item de compra guarda **cópia** da embalagem ("Caixa 12") e da quantidade convertida, sem chave estrangeira para a embalagem | Embalagens podem ser removidas do cadastro sem quebrar o histórico. |
| 43 | Pratos sem controle de estoque não entram em compras | Não há estoque a repor. |

## Etapa 7 — Dashboard, relatórios e despesas

| # | Decisão | Motivo |
|---|---|---|
| 44 | ~~**Dados de demonstração** ligáveis em Configurações (padrão: ligado), com faixa de aviso nas telas | Pedido do responsável, para apresentações; desligado, tudo vem dos dados reais. *(removido — ver 67)* |
| 45 | Simulação **determinística** (o mesmo dia gera sempre os mesmos números) e **consistente** (séries, rankings e totais vêm das mesmas vendas simuladas) | Números estáveis e coerentes na apresentação. *(removido — ver 67)* |
| 46 | Um único endpoint (`/relatorios/painel`) serve dashboard e relatórios: indicadores, séries por dia e hora, formas de pagamento, categorias, mais vendidos/lucrativos, baixo giro e estoque | Simplicidade; cada tela usa o que precisa. |
| 47 | Faturamento só com **vendas concluídas**; **lucro bruto** = vendas − custo dos produtos; **lucro líquido** = lucro bruto − despesas do período, com aviso de que só é completo com todas as despesas lançadas | Diferenciar margem bruta de lucro líquido (requisito). |
| 48 | Variação do faturamento contra o **período anterior de mesma duração**; datas no fuso do bar; consulta limitada a 400 dias | Comparação justa e consultas leves. |
| 49 | **Despesas** com categorias fixas (água, luz, gás, aluguel, manutenção, limpeza, funcionários, impostos, outros), navegação por mês | Cadastro simples. |
| 50 | Após o login, a tela inicial é o **Dashboard** | Pedido do responsável. |

## Etapa 6 — Pedidos pelo cardápio digital

| # | Decisão | Motivo |
|---|---|---|
| 51 | **App separado** (`apps/cardapio`, Flutter Web em `/cardapio/`), sem login e sem nenhum código do painel | Bundle menor no celular do cliente e nada administrativo exposto. |
| 52 | QR Code por mesa com o local no link (`/cardapio/?mesa=12`, `?local=Balcão`), gerado e impresso em **Configurações** | O cliente não precisa digitar a mesa. |
| 53 | Aparecem no cardápio os produtos **ativos, vendáveis, com preço, marcados "Vende no cardápio"** e de **categoria visível no cardápio**; produto controlado sem saldo disponível aparece como **esgotado** | Controle do que o cliente vê, sem expor custo nem estoque exato. |
| 54 | O **preço é definido pelo servidor** no envio e fica congelado no pedido; a venda gerada usa esse preço, mesmo que o cadastro mude depois | O cliente paga o que viu; o app não envia preços. |
| 55 | Envio **idempotente** (chave gerada por carrinho); limites: até 30 itens, 1–50 unidades por item, textos curtos; **até 20 pedidos por IP a cada 10 minutos** (IP real informado pelo nginx); chave "cardápio aberto" em Configurações | Evita duplicidade e abuso sem exigir cadastro do cliente. |
| 56 | Pedido **não é venda**. Status de **preparo** (Recebido → Aceito → Em preparo → Pronto → Entregue, ou Cancelado) e **financeiro** (Pendente → Pago, ou Cancelado) são independentes | Requisito: só entra no faturamento ao pagar. |
| 57 | **Reserva de estoque no aceite** (não no envio): o disponível do PDV diminui; sem saldo, o aceite falha e nada muda. Recusa/cancelamento liberam a reserva | Pedidos falsos não bloqueiam produtos; o que foi prometido ao cliente não é vendido no balcão. |
| 58 | **Receber pagamento** (a partir do aceite, antes ou depois da entrega): trava o pedido, exige caixa aberto, libera a reserva e gera a **venda** (que baixa o estoque) com chave de idempotência = id do pedido; `venda.pedido_id` é único | Um pedido nunca gera duas vendas, mesmo com clique duplo. |
| 59 | Pedido pago não é cancelado pela tela de pedidos: para desfazer, cancela-se a **venda** (estorno de estoque) | Uma única regra de estorno. |
| 60 | Painel de pedidos em **kanban** com atualização a cada 10 s e destaque de pedidos novos; o cliente acompanha o status a cada 8 s, e o celular lembra os últimos pedidos | Sem WebSocket: simples e suficiente para o volume de um bar. |
| 61 | Cardápio **priorizando o navegador do celular**: tela de carregamento imediata no `index.html` (removida no primeiro quadro do Flutter), rotas nomeadas (`#/pedido/…`) para o botão "voltar" do celular funcionar e o link do pedido poder ser reaberto, motor gráfico servido pelo próprio servidor (`--no-web-resources-cdn`) | O cliente usa o próprio celular, muitas vezes com rede fraca; nada de tela branca nem dependência de CDN externo. |
| 62 | **Preço promocional** no produto, com data de término opcional (inclusive, no fuso do bar). Vale em todo lugar: PDV, cardápio e pedidos cobram o promocional; o preço normal aparece riscado | Uma regra só de preço; o cliente paga o que viu. |
| 63 | **"Sugestão da casa"**: marcação manual no cadastro do produto | Destaque escolhido pelo bar. |
| 64 | **Vitrine do cardápio configurável** (Configurações): seções Sugestões, Promoções, Mais pedidos, Menos pedidos e Novidades — liga/desliga, ordem, título e quantidade. O conteúdo é automático: promoções por maior desconto, mais/menos pedidos pelas vendas concluídas dos últimos 30 dias, novidades pela data de cadastro. Esgotados não entram na vitrine | Pedido do responsável: mudar o foco do dia (ex.: destacar os menos vendidos) sem mexer em produtos. |
| 65 | Com dados de demonstração ligados e menos de 3 produtos vendidos, "Mais pedidos" é completado com produtos do cardápio (com foto primeiro) | A seção aparece nas apresentações mesmo sem vendas reais. *(removido — ver 67)* |
| 66 | Visual do cardápio: preto quente e dourado, títulos em **Playfair Display** (fonte empacotada no app, licença OFL), carrossel para a primeira seção da vitrine, busca, filtros (promoções e categorias) e ordenação | Identidade de bar sofisticado, sem depender de fontes externas. |
| 67 | **Dados de demonstração removidos**: dashboard, relatórios e "Mais pedidos" do cardápio usam sempre os dados reais; a configuração `dados_demonstracao` foi apagada (V10) | Pedido do responsável, para operar com os números reais do bar. |
