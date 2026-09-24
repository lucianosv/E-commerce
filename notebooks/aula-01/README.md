# Aula 1: SQL & Dashboard

> **Objetivo do dia:** responder os três diretores usando SQL e entregar as respostas em um dashboard com uma página por diretoria.

| | |
|---|---|
| **Notebooks** | [`00_o_desafio.sql`](./00_o_desafio.sql): o desafio inteiro (os diretores, os dados, as 12 perguntas e a entrega)<br>[`01_sql_e_dashboard.sql`](./01_sql_e_dashboard.sql): a resolução, passo a passo |
| **Apoio** | [`dashboard/`](./dashboard/) (dashboard pronto para importar) |
| **Duração** | ~100 minutos |
| **Pré-requisito** | Conta no Databricks Free Edition (veja o [README principal](../README.md#antes-da-aula-1-crie-sua-conta-5-minutos)) |

## Roteiro

| Bloco | Tempo | O que acontece |
|---|---|---|
| Contexto | 10 min | O e-commerce, os 3 diretores e as perguntas |
| Setup | 10 min | Catálogo, schemas e upload dos CSVs como tabelas |
| CSV × Tabela | 5 min | Por que uma tabela Delta é melhor que um arquivo |
| Diretoria de Vendas | 25 min | `SELECT`, `LIMIT`, `ORDER BY`, `WHERE`, agregações, `GROUP BY`, `JOIN` |
| Diretoria de Clientes | 15 min | Top 10 clientes, clientes por estado |
| Diretoria de Pricing | 15 min | Nosso preço contra o dos concorrentes, `HAVING` |
| Dashboard | 15 min | Uma página por diretoria, publicada |
| Bônus | em casa | `CASE WHEN` e window functions |

---

## Parte 1: base teórica

### O que é o Databricks e por que usar aqui

O Databricks é uma plataforma onde armazenamento, processamento, SQL, Python, dashboards e IA ficam no mesmo lugar. Na versão antiga desta imersão usávamos um banco PostgreSQL (Supabase) e ferramentas separadas para cada etapa. Aqui, os 4 dias acontecem na mesma plataforma: o que você cria hoje vira insumo do pipeline de amanhã e do Genie do último dia.

A **Free Edition** é gratuita e não exige cartão de crédito. Ela tem limites de tamanho de máquina e de uso diário, que ficam muito acima do que este projeto precisa.

### Data warehouse, data lake e lakehouse

| | Data warehouse | Data lake | Lakehouse |
|---|---|---|---|
| Guarda | Tabelas estruturadas | Qualquer arquivo | Os dois |
| Custo de armazenamento | Alto | Baixo | Baixo |
| Garante tipos e consistência | Sim | Não | Sim |
| Bom para | Relatórios e SQL | Dados brutos, ciência de dados | Tudo isso |

O **lakehouse** guarda os dados como arquivos baratos (como um lake), mas com uma camada de organização por cima que dá tabelas, SQL, histórico e controle de acesso (como um warehouse). No Databricks, essa camada é o **Unity Catalog** mais o formato de tabela **Delta**.

### Unity Catalog: o endereço de cada dado

Todo dado no Databricks tem um endereço de três partes:

```
catálogo  .  schema  .  tabela
ecommerce .  bronze  .  vendas
```

- **Catálogo:** o nível mais alto, geralmente um projeto ou uma área da empresa (`ecommerce`).
- **Schema:** um agrupamento dentro do catálogo. Aqui, um por camada: `bronze`, `silver` e `gold`.
- **Tabela / view / volume:** onde o dado de fato está.

Hoje os CSVs entram direto como **tabelas** na camada **bronze**, pela tela de upload do Databricks. A bronze é a primeira camada: o dado exatamente como chegou da origem. Na Aula 2 você vai conhecer o **volume**, uma pasta governada para guardar os arquivos originais antes de virarem tabela.

### Por que transformar o CSV em tabela?

Um CSV é texto. Qualquer pessoa pode abri-lo e escrever "duas" onde deveria estar `2`, e ninguém fica sabendo até o relatório quebrar. Uma **tabela Delta** tem três superpoderes, e você vai ver cada um na prática:

1. **Schema (contrato):** cada coluna tem um tipo. Tentar gravar texto em uma coluna `INT` dá erro na hora.
2. **Histórico:** toda alteração vira uma versão, visível com `DESCRIBE HISTORY`.
3. **Time travel:** dá para consultar a tabela como ela era (`VERSION AS OF 0`) e voltar no tempo (`RESTORE`).

### SQL é declarativo

Em SQL você descreve **o que** quer, não **como** buscar:

```sql
SELECT nome_produto, preco_atual   -- quais colunas
FROM ecommerce.bronze.produtos     -- de onde
ORDER BY preco_atual DESC          -- em que ordem
LIMIT 10;                          -- quantas linhas
```

O motor decide a melhor forma de executar. Leia a consulta como uma frase: "selecione nome e preço dos produtos, ordene pelo preço do maior para o menor e me dê 10".

### A ordem em que o SQL realmente executa

Você escreve em uma ordem, mas o banco executa em outra. Entender isso resolve metade dos erros de iniciante:

| Ordem de escrita | Ordem de execução | O que faz |
|---|---|---|
| 1. `SELECT` | 5 | Escolhe e calcula as colunas |
| 2. `FROM` / `JOIN` | **1** | Junta as tabelas |
| 3. `WHERE` | **2** | Filtra **linhas** |
| 4. `GROUP BY` | **3** | Agrupa |
| 5. `HAVING` | **4** | Filtra **grupos** |
| 6. `ORDER BY` | 6 | Ordena |
| 7. `LIMIT` | 7 | Corta |

Por isso não dá para usar `SUM(...)` no `WHERE`: quando o `WHERE` roda, os grupos ainda nem existem. Para filtrar por um total, use `HAVING`.

### Agregação e a regra de ouro do `GROUP BY`

Funções de agregação (`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`) transformam muitas linhas em um número. Com `GROUP BY`, a mesma conta é feita **separadamente por grupo**.

> **Regra de ouro:** toda coluna do `SELECT` precisa estar no `GROUP BY` ou dentro de uma agregação.

### JOIN: juntando tabelas

A tabela `vendas` guarda só o `id_produto`. O nome e a categoria estão em `produtos`. O `JOIN` usa a coluna em comum como ponte.

| Tipo | Retorna | Quando usar |
|---|---|---|
| `INNER JOIN` (ou só `JOIN`) | Só as linhas que existem **nas duas** tabelas | Quando você quer apenas o que casa |
| `LEFT JOIN` | **Todas** as linhas da esquerda, com `NULL` onde não casou | Quando não pode perder nada da tabela principal |

A aula tem uma pegadinha de propósito: a receita **com** `JOIN` (R$ 969.837,27) é menor que a receita **sem** `JOIN` (R$ 974.077,28). A diferença são 20 vendas de produtos que não estão no catálogo, e o `INNER JOIN` as descarta em silêncio. Isso é um **problema de qualidade de dados**, e ele volta nas Aulas 2 e 3.

### Dashboard AI/BI

Um dashboard do Databricks é feito de **datasets** (consultas SQL) e **widgets** (gráficos, tabelas, indicadores e filtros) que leem esses datasets. Ele roda no SQL warehouse, então mostra sempre o dado atual da tabela. Depois de publicado, qualquer pessoa com acesso vê os números sem abrir notebook nenhum.

---

## Parte 2: passo a passo

### 1. Leia o desafio

Abra `aula-01-sql-dashboard/00_o_desafio`. Ele não tem código para rodar: apresenta a empresa, os três diretores, as tabelas e as 12 perguntas que você vai responder, cada uma com o conceito de SQL que a resolve. Se quiser, tente responder algumas sozinho antes de ver a resolução.

### 2. Abra o notebook da resolução

- **Com Git folder** (recomendado): **Workspace → Create → Git folder**, cole a URL do repositório e abra `aula-01-sql-dashboard/01_sql_e_dashboard`.
- **Sem Git:** baixe [`00_o_desafio.sql`](./00_o_desafio.sql) e [`01_sql_e_dashboard.sql`](./01_sql_e_dashboard.sql) e use **Workspace → Import**.

No canto superior direito, conecte o notebook em **Serverless**. Rode célula por célula com `Shift + Enter`.

### 3. Setup

A primeira célula de código cria o catálogo e os schemas. Depois, suba os 4 CSVs da pasta [`dados/`](../dados/) como tabelas, **um de cada vez**:

1. **+ New → Add or upload data → Create or modify table**.
2. Arraste o CSV (`vendas.csv`, `produtos.csv`, `clientes.csv` ou `preco_competidores.csv`).
3. No topo, escolha o catálogo **`ecommerce`** e o schema **`bronze`**. Mantenha o nome da tabela sugerido (igual ao do arquivo).
4. Confira a prévia dos tipos das colunas e clique em **Create table**.

Volte ao notebook e rode o `SHOW TABLES` e a contagem: 3.020 vendas, 215 produtos, 50 clientes e 728 preços.

### 4. Siga o notebook

Cada bloco começa com a pergunta do diretor, em texto, e segue com as consultas. **A célula do `INSERT` com `'duas'` vai dar erro, e esse erro é o objetivo**: é a tabela protegendo o dado.

### 5. Monte o dashboard

**Opção A, importar pronto (2 min):**
1. Baixe [`dashboard/diretoria_ecommerce.lvdash.json`](./dashboard/diretoria_ecommerce.lvdash.json).
2. **Dashboards → seta ao lado de Create dashboard → Import dashboard from file**.
3. Clique em **Publish**. As consultas já apontam para `ecommerce.bronze`.

**Opção B, montar do zero (15 min, recomendado para aprender):**
1. **Dashboards → Create dashboard**. Renomeie para *Diretoria E-commerce*.
2. Aba **Data → Create from SQL**. Crie um dataset para cada diretoria usando as consultas do notebook `01_sql_e_dashboard`.
3. Volte ao canvas e crie **3 páginas**: Vendas, Clientes e Pricing.
4. Em cada página, adicione:
   - **Vendas:** indicadores de receita, vendas e ticket médio; linha de receita diária por canal; barras de receita por categoria; tabela com o top 10 de produtos.
   - **Clientes:** indicadores de clientes e receita média; barras de receita por estado; tabela com o ranking de clientes.
   - **Pricing:** indicadores de produtos monitorados e "mais caros que todos"; barras de diferença média por categoria; tabela de alerta.
5. **Publish** e compartilhe o link.

---

## Parte 3: confira seus resultados

Se os seus números baterem com estes, você fez tudo certo.

| Pergunta | Resposta esperada |
|---|---|
| Receita total | **R$ 974.077,28** em 3.020 vendas |
| Ticket médio | **R$ 322,54** |
| Clientes que compraram | 50 |
| Canal que mais vende | **E-commerce**: 2.155 vendas e R$ 705.486,21 (loja física: 865 e R$ 268.591,07) |
| Categoria com mais receita | **Moda** (R$ 248.124,15), depois Áudio e Acessórios |
| Produto com mais receita | **Fone de Ouvido Esportivo** (R$ 120.457,54 somando pelo nome) |
| Vendas de produtos não cadastrados | **20 vendas**, R$ 4.240,01 |
| Estado com mais receita | **AM** (R$ 79.474,67), depois TO |
| Melhor cliente | **Ana Sophia Pereira** (MG), R$ 30.716,63 |
| Produtos mais caros que todos os concorrentes | **35** |
| Categoria mais cara que o mercado | **Tênis**, 100% acima da média dos concorrentes |

> **Pegadinha do nome duplicado:** existem produtos diferentes com o mesmo nome. Somando pelo `nome_produto`, o Fone de Ouvido Esportivo faz R$ 120.457,54; somando pelo `id_produto` (como a camada gold faz na Aula 2), o maior produto individual faz R$ 116.462,65. Os dois estão certos para perguntas diferentes. Contar pelo identificador é o padrão.

---

## Erros comuns

| Erro | Causa | Como resolver |
|---|---|---|
| `TABLE_OR_VIEW_NOT_FOUND` | Esqueceu de rodar a célula que cria as tabelas | Rode o bloco "CSV × Tabela" |
| `MISSING_AGGREGATION` | Coluna no `SELECT` fora do `GROUP BY` | Aplique a regra de ouro |
| `CAST_INVALID_INPUT` no `INSERT` | É o erro esperado da demonstração | Siga para a próxima célula |
| Receita diferente da tabela acima | Usou `JOIN` onde devia ser sem `JOIN` (ou o contrário) | Releia a pegadinha do `JOIN` |

---

## Para praticar

1. Qual marca gera mais receita?
2. Qual é o ticket médio da loja física em cada dia da semana?
3. Quais produtos nunca foram vendidos? (dica: `LEFT JOIN` a partir de `produtos`)
4. Qual concorrente tem o menor preço médio?
5. **Bônus:** refaça a segmentação de clientes do fim do notebook e descubra quantos são VIP.

## Amanhã

Hoje você subiu os CSVs na mão. E quando chegar arquivo novo todo dia? Na [Aula 2](../aula-02-python-engenharia/) o dado passa a **chegar sozinho**.
