# Aula 4: Genie

> **Objetivo do dia:** os diretores perguntam em português e recebem a resposta certa, direto da camada gold, sem abrir ticket para ninguém.
>
> **No dia 1 você respondeu o diretor. No dia 4 ele não precisa mais de você para perguntar.**

| | |
|---|---|
| **Material** | [`01_preparar_dados_para_ia.sql`](./01_preparar_dados_para_ia.sql), [`genie/diretoria_ecommerce.geniespace.json`](./genie/diretoria_ecommerce.geniespace.json) e [`perguntas_demo.md`](./perguntas_demo.md) |
| **Duração** | ~60 minutos de conteúdo |
| **Pré-requisito** | Camada gold criada (Aula 2) |

## Roteiro

| Bloco | Tempo | O que acontece |
|---|---|---|
| Teoria | 15 min | Como uma IA transforma pergunta em SQL e por que ela erra |
| Preparar o dado | 15 min | Comentários em tabelas e colunas |
| Criar o Genie | 15 min | Tabelas, instruções, perguntas de exemplo e SQL de referência |
| Demonstração | 15 min | As 10 perguntas, da fácil à difícil, e os limites |

---

## Parte 1: base teórica

### Todo mundo quer IA. Ninguém tem o dado organizado.

A maior parte dos projetos de "IA para dados" falha pelo mesmo motivo: a IA recebe tabelas com nomes crípticos, colunas sem descrição, regras de negócio que só existem na cabeça de alguém, e é obrigada a adivinhar. Você passou três dias fazendo o contrário: dado limpo, tabelas com um propósito, regras escritas e testadas. **É por isso que o Genie vai acertar.**

### Como o Genie funciona

O Genie é um assistente de *text-to-SQL*: transforma uma pergunta em linguagem natural em uma consulta SQL, executa no SQL warehouse e explica o resultado.

```
"Quantos clientes VIP temos?"
        │
        ▼
 1. Lê o contexto do space ──► tabelas, comentários, instruções, exemplos
 2. Um modelo de linguagem escreve o SQL
 3. O SQL roda no warehouse, com as SUAS permissões do Unity Catalog
 4. Devolve tabela, gráfico e um resumo em português
        │
        ▼
"10 clientes VIP, que representam 27% da receita."
```

Três coisas importantes:

- **O Genie não "sabe" nada sobre a sua empresa.** Tudo o que ele sabe vem do que você coloca no space.
- **O SQL fica visível.** Todo resultado tem o botão **Show code**. Isso é o que permite confiar (ou desconfiar) da resposta.
- **As permissões continuam valendo.** Quem não pode ver uma tabela no Unity Catalog também não vê pelo Genie.

### O que faz o Genie acertar

| Camada de contexto | O que é | Exemplo neste projeto |
|---|---|---|
| **Tabelas certas** | Poucas tabelas, cada uma com um propósito | As 4 tabelas gold, e não as 11 da bronze e da silver |
| **Comentários** | Descrição de cada tabela e coluna no Unity Catalog | `receita`: "Receita bruta em reais (R$) = quantidade × preço unitário" |
| **Instruções** | Regras gerais, em texto | "Não existe lucro nos dados"; "o período vai de 13/12/2025 a 11/01/2026" |
| **SQL de exemplo** | Pares pergunta → SQL certo | Como calcular ticket médio sem errar a conta |
| **Joins** | Como as tabelas se relacionam | `vendas_produtos.id_produto = precos_competitividade.id_produto` |
| **Sinônimos** | Palavras do negócio que apontam para uma coluna | "faturamento" → `receita`; "UF" → `estado` |

A ordem importa: **comentário bom resolve mais que instrução longa.** Instrução é para regra de negócio que não cabe em uma coluna.

### Os erros clássicos de text-to-SQL (e como este projeto evita cada um)

| Erro | Exemplo | Como evitamos |
|---|---|---|
| Somar o que não se soma | Somar `clientes_unicos` de vários dias | Comentário da coluna: "Não somar entre linhas" |
| Usar a data de hoje | "Vendas da última semana" com `current_date()` | Instrução: os dados terminam em 11/01/2026 |
| Contar pelo nome | Produtos diferentes com o mesmo nome | Instrução: contar por `id_produto` |
| Média de médias | Ticket médio = `AVG(ticket_medio)` | SQL de exemplo com `SUM(receita) / SUM(total_vendas)` |
| Inventar métrica | "Qual o lucro?" | Instrução: só existe receita |
| Comparar totais desiguais | Sábado "vende mais" porque o período tem 5 sábados | Instrução: mostrar também a média por dia |

### Dashboard × Genie

| | Dashboard | Genie |
|---|---|---|
| Pergunta | Definida por quem montou | Livre, do usuário |
| Melhor para | Acompanhar os mesmos números todo dia | Perguntas novas, exploração |
| Risco | Não responder o que ninguém previu | Responder errado com confiança |
| Controle | Total | Depende do contexto que você deu |

Os dois se completam. No dashboard dá até para ligar um botão **Ask Genie** que leva o diretor do gráfico para a conversa.

---

## Parte 2: passo a passo

### 1. Documente o dado para a IA

Abra [`01_preparar_dados_para_ia.sql`](./01_preparar_dados_para_ia.sql) e rode. Compare o `DESCRIBE TABLE` do começo (comentários vazios) com o do fim.

> Esse notebook também é a **última tarefa do Job diário**. Como a gold é recriada todo dia com `CREATE OR REPLACE`, os comentários precisam ser reaplicados depois dela.

### 2. Crie o Genie space

**Pela interface (recomendado na aula ao vivo):**

1. Menu lateral **Genie → New**.
2. **Data:** adicione `ecommerce.gold.vendas_temporais`, `vendas_produtos`, `clientes_segmentacao` e `precos_competitividade`. Warehouse: *Serverless Starter Warehouse*.
3. Título: **Diretoria E-commerce**.
4. **Instructions → General instructions:** cole o texto de `instructions.text_instructions` do arquivo [`genie/diretoria_ecommerce.geniespace.json`](./genie/diretoria_ecommerce.geniespace.json).
5. **Instructions → SQL queries:** adicione os pares pergunta → SQL de `example_question_sqls`.
6. **Instructions → Joins:** `vendas_produtos.id_produto = precos_competitividade.id_produto` (um para um).
7. **Settings → Sample questions:** as 6 perguntas de `config.sample_questions`.
8. Salve e faça a primeira pergunta.

**Como código (Aula 3):** o mesmo space já está no bundle, em [`resources/diretoria.genie_space.yml`](../resources/diretoria.genie_space.yml). Um `databricks bundle deploy -t prod` cria ou atualiza tudo a partir do JSON.

### 3. A demonstração

Siga [`perguntas_demo.md`](./perguntas_demo.md): 10 perguntas da mais fácil para a mais difícil, cada uma com a resposta esperada e o SQL de referência. Depois, as perguntas que mostram os limites ("qual o lucro?").

Para cada resposta, clique em **Show code** e leia o SQL com a turma. Esse hábito é o que separa quem usa IA de quem é enganado por ela.

### 4. Compartilhe com os diretores

**Share** → adicione as pessoas com permissão **Can run**. Elas também precisam de `SELECT` nas tabelas gold e de acesso ao warehouse.

---

## Parte 3: resultados esperados

O Genie deste projeto acertou **10 de 10** perguntas da demonstração. As principais respostas:

| Pergunta | Resposta |
|---|---|
| Receita total | R$ 974.077,28 |
| Canal que vende mais | E-commerce, R$ 705.486,21 |
| Categoria com mais receita | Moda, R$ 248.124,15 |
| Clientes VIP | 10 clientes, 27,0% da receita |
| Região com mais receita | Norte, R$ 333.078,69 |
| Produtos mais caros que todos os concorrentes | 35 (15 são Tênis) |

---

## Erros comuns

| Sintoma | Causa provável | Como resolver |
|---|---|---|
| "I don't have access to..." | Sem `SELECT` na tabela ou sem acesso ao warehouse | Conceda permissão no Unity Catalog |
| Resposta com a data de hoje | Faltou a instrução do período | Revise as instruções |
| Números diferentes da tabela acima | Pipeline não rodou depois de mudanças | Rode o Job e pergunte de novo |
| Genie pede esclarecimento | Pergunta ambígua | Responda na mesma conversa; se for recorrente, vire instrução ou exemplo |

---

## Fechando a imersão

| Dia | Você | O diretor |
|---|---|---|
| 1 | Respondeu com SQL e publicou um dashboard | Esperou você |
| 2 | Automatizou a chegada do dado | Recebeu o número atualizado todo dia |
| 3 | Profissionalizou com Git, testes e deploy | Passou a confiar no número |
| 4 | Organizou o dado para a IA | **Pergunta sozinho** |

O que você construiu nesses 4 dias é exatamente o que as empresas estão tentando fazer agora: um dado organizado o suficiente para a IA trabalhar em cima dele.
