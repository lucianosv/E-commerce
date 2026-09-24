-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Aula 1: SQL & Dashboard
-- MAGIC ### Imersão Jornada de Dados no Databricks
-- MAGIC
-- MAGIC Uma empresa de e-commerce acabou de abrir a operação digital. Três diretores têm perguntas **hoje**, e ninguém ainda olhou para os dados.
-- MAGIC
-- MAGIC Neste notebook você vai responder cada um deles com SQL e, no fim, montar um **dashboard** com uma página por diretoria.
-- MAGIC
-- MAGIC > Ainda não leu o desafio? Comece pelo notebook **`00_o_desafio`**: ele apresenta a empresa, os diretores, os dados e as 12 perguntas.
-- MAGIC
-- MAGIC | Bloco | Tempo | O que acontece |
-- MAGIC |---|---|---|
-- MAGIC | 0. Setup | antes da aula | Catálogo, schemas e upload das 4 tabelas |
-- MAGIC | 1. CSV × Tabela | 5 min | Por que dado em tabela é diferente de dado em arquivo |
-- MAGIC | 2. Diretoria de Vendas | 25 min | `SELECT`, `LIMIT`, `ORDER BY`, `WHERE`, agregações, `GROUP BY`, `JOIN` |
-- MAGIC | 3. Diretoria de Clientes | 15 min | Top 10 clientes, clientes por estado |
-- MAGIC | 4. Diretoria de Pricing | 15 min | Nosso preço × preço dos concorrentes |
-- MAGIC | 5. Dashboard | 15 min | Uma página por diretoria |
-- MAGIC | Bônus | casa | `CASE WHEN` e window functions |
-- MAGIC
-- MAGIC > **Como rodar:** conecte o notebook em **Serverless** (canto superior direito) e execute célula por célula com `Shift + Enter`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Os três diretores
-- MAGIC
-- MAGIC **Diretor Comercial (Vendas)**
-- MAGIC > "Quanto vendemos no mês? Qual canal vende mais, o e-commerce ou a loja física? Quais produtos e categorias puxam a receita?"
-- MAGIC
-- MAGIC **Diretora de Customer Success (Clientes)**
-- MAGIC > "Quem são nossos 10 melhores clientes? De quais estados eles são? Preciso planejar a equipe regional."
-- MAGIC
-- MAGIC **Diretor de Pricing (Preços)**
-- MAGIC > "Estamos mais caros que a concorrência? Quais produtos estão mais caros que **todos** os concorrentes?"
-- MAGIC
-- MAGIC Hoje essas perguntas levam dias para serem respondidas. No fim desta aula elas estarão em um painel.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC # 0. Setup
-- MAGIC
-- MAGIC No Databricks os dados são organizados em três níveis, pelo **Unity Catalog**:
-- MAGIC
-- MAGIC ```
-- MAGIC catálogo  →  schema  →  tabela
-- MAGIC ecommerce →  bronze  →  vendas, produtos, clientes, preco_competidores
-- MAGIC ```
-- MAGIC
-- MAGIC A **bronze** é a primeira camada: o dado exatamente como chegou da origem. Hoje ele chega pelo upload que você mesmo vai fazer. Os schemas `silver` e `gold` ficam prontos para a Aula 2.

-- COMMAND ----------

CREATE CATALOG IF NOT EXISTS ecommerce COMMENT 'Imersão Jornada de Dados: e-commerce';

CREATE SCHEMA IF NOT EXISTS ecommerce.bronze COMMENT 'Dados como chegaram da origem';
CREATE SCHEMA IF NOT EXISTS ecommerce.silver COMMENT 'Aula 2: dados limpos e padronizados';
CREATE SCHEMA IF NOT EXISTS ecommerce.gold   COMMENT 'Aula 2: tabelas prontas para o negócio';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Subir os 4 CSVs como tabelas
-- MAGIC
-- MAGIC Baixe `produtos.csv`, `clientes.csv`, `vendas.csv` e `preco_competidores.csv` da pasta `dados/` do repositório. Para **cada arquivo**:
-- MAGIC
-- MAGIC 1. Clique em **+ New → Add or upload data → Create or modify table**.
-- MAGIC 2. Arraste o CSV.
-- MAGIC 3. No topo da tela, escolha o catálogo **`ecommerce`** e o schema **`bronze`**. O nome da tabela já vem do arquivo (`vendas`, `produtos`...): mantenha.
-- MAGIC 4. Confira a prévia: o Databricks já detectou o tipo de cada coluna (texto, número, data).
-- MAGIC 5. Clique em **Create table**.
-- MAGIC
-- MAGIC Confira se as 4 tabelas chegaram:

-- COMMAND ----------

SHOW TABLES IN ecommerce.bronze;

-- COMMAND ----------

SELECT 'vendas' AS tabela, COUNT(*) AS linhas FROM ecommerce.bronze.vendas
UNION ALL SELECT 'produtos', COUNT(*) FROM ecommerce.bronze.produtos
UNION ALL SELECT 'clientes', COUNT(*) FROM ecommerce.bronze.clientes
UNION ALL SELECT 'preco_competidores', COUNT(*) FROM ecommerce.bronze.preco_competidores;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Esperado: 3.020 vendas, 215 produtos, 50 clientes e 728 preços de concorrentes.
-- MAGIC
-- MAGIC ---
-- MAGIC # 1. CSV × Tabela
-- MAGIC
-- MAGIC O upload não guardou o seu CSV. Ele **transformou** o arquivo em uma **tabela Delta**, e isso muda tudo. Um CSV é só texto: qualquer um pode abrir e escrever "duas" na coluna de quantidade, e ninguém fica sabendo até o relatório quebrar. Uma tabela Delta tem três superpoderes:
-- MAGIC
-- MAGIC | Superpoder | O que significa |
-- MAGIC |---|---|
-- MAGIC | **Contrato (schema)** | Cada coluna tem um tipo, e a tabela recusa o que não se encaixa |
-- MAGIC | **Histórico** | Toda alteração vira uma versão |
-- MAGIC | **Time travel** | Dá para consultar e voltar a qualquer versão |
-- MAGIC
-- MAGIC Veja o contrato da tabela `vendas`:

-- COMMAND ----------

DESCRIBE TABLE ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### A tabela se protege
-- MAGIC
-- MAGIC Tente inserir uma venda com a quantidade escrita por extenso. **Esta célula vai dar erro, e o erro é o objetivo.**

-- COMMAND ----------

INSERT INTO ecommerce.bronze.vendas (id_venda, data_venda, id_cliente, id_produto, canal_venda, quantidade, preco_unitario)
VALUES ('sal_teste', current_timestamp(), 'cus_teste', 'prd_teste', 'ecommerce', 'duas', 99.90);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC O Databricks recusou o valor `'duas'` porque a coluna `quantidade` é numérica. Em um CSV esse erro passaria em silêncio e quebraria o relatório de alguém no mês seguinte.
-- MAGIC
-- MAGIC ### A tabela lembra do passado
-- MAGIC
-- MAGIC Toda alteração em uma tabela Delta vira uma **versão**. Vamos fazer uma alteração válida e olhar o histórico.

-- COMMAND ----------

UPDATE ecommerce.bronze.vendas
SET canal_venda = 'ECOMMERCE'
WHERE canal_venda = 'ecommerce';

-- COMMAND ----------

DESCRIBE HISTORY ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC A versão 0 é o upload. A versão 1 é o `UPDATE`. Ops, padronizamos o canal errado. Dá para consultar a versão anterior (**time travel**) e voltar a tabela para ela:

-- COMMAND ----------

SELECT canal_venda, COUNT(*) AS vendas
FROM ecommerce.bronze.vendas VERSION AS OF 0
GROUP BY canal_venda;

-- COMMAND ----------

RESTORE TABLE ecommerce.bronze.vendas TO VERSION AS OF 0;

-- COMMAND ----------

SELECT canal_venda, COUNT(*) AS vendas
FROM ecommerce.bronze.vendas
GROUP BY canal_venda;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC # 2. Diretoria de Vendas
-- MAGIC
-- MAGIC > "Quanto vendemos no mês? Qual canal vende mais? Quais produtos e categorias puxam a receita?"
-- MAGIC
-- MAGIC Vamos construir as respostas **aos poucos**. Cada consulta nova acrescenta **uma** peça à anterior. Leia o texto, rode a célula e compare com o resultado da célula de cima.
-- MAGIC
-- MAGIC ## Pergunta 01 · Que dados temos? (`SELECT`)
-- MAGIC
-- MAGIC Toda consulta começa com duas palavras:
-- MAGIC
-- MAGIC - `SELECT`: **quais colunas** eu quero ver;
-- MAGIC - `FROM`: **de qual tabela**.
-- MAGIC
-- MAGIC O `*` significa "todas as colunas". Leia em voz alta: *"selecione todas as colunas da tabela vendas"*.

-- COMMAND ----------

SELECT *
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Cada linha é **uma venda**. Repare nas colunas:
-- MAGIC
-- MAGIC | Coluna | O que é |
-- MAGIC |---|---|
-- MAGIC | `id_venda` | O "RG" da venda |
-- MAGIC | `data_venda` | Dia e hora |
-- MAGIC | `id_cliente` / `id_produto` | Quem comprou e o que comprou (só o código!) |
-- MAGIC | `canal_venda` | `ecommerce` (site) ou `loja_fisica` |
-- MAGIC | `quantidade` | Quantas unidades |
-- MAGIC | `preco_unitario` | Preço de cada unidade |
-- MAGIC
-- MAGIC Na prática, quase nunca queremos todas as colunas. Em vez do `*`, escreva só as que interessam, separadas por vírgula:

-- COMMAND ----------

SELECT
  id_venda,
  canal_venda,
  quantidade,
  preco_unitario
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Criando uma coluna nova
-- MAGIC
-- MAGIC A tabela **não tem** a receita da venda. Mas dá para calcular na hora: `quantidade * preco_unitario`.
-- MAGIC
-- MAGIC O `AS` dá um nome para a coluna calculada. Sem ele, a coluna aparece com o nome da conta, o que fica feio.

-- COMMAND ----------

SELECT
  id_venda,
  canal_venda,
  quantidade,
  preco_unitario,
  quantidade * preco_unitario AS receita
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC > **Sua vez:** mude o `AS receita` para `AS valor_da_venda` e rode de novo. O que mudou?
-- MAGIC
-- MAGIC ## Pergunta 02 · Quais foram as maiores vendas? (`ORDER BY`)
-- MAGIC
-- MAGIC `ORDER BY` ordena o resultado por uma coluna, como o "classificar" do Excel.
-- MAGIC
-- MAGIC - `ASC` (padrão): do menor para o maior;
-- MAGIC - `DESC`: do maior para o menor.
-- MAGIC
-- MAGIC Mesma consulta de antes, com **uma linha a mais** no fim:

-- COMMAND ----------

SELECT
  id_venda,
  canal_venda,
  quantidade,
  preco_unitario,
  quantidade * preco_unitario AS receita
FROM ecommerce.bronze.vendas
ORDER BY receita DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 03 · Me mostra só as 10 primeiras (`LIMIT`)
-- MAGIC
-- MAGIC A tabela tem 3.020 vendas, e ninguém quer ler 3.020 linhas. `LIMIT` corta o resultado. Junto com `ORDER BY`, ele vira o famoso **top N**.

-- COMMAND ----------

SELECT
  id_venda,
  canal_venda,
  quantidade,
  preco_unitario,
  quantidade * preco_unitario AS receita
FROM ecommerce.bronze.vendas
ORDER BY receita DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC > **Sua vez:** troque `DESC` por `ASC`. Quais são as 10 **menores** vendas?
-- MAGIC
-- MAGIC ## Pergunta 04 · E só as vendas da loja física? (`WHERE`)
-- MAGIC
-- MAGIC `WHERE` **filtra linhas**: só passam as que atendem à condição. Texto vai entre aspas simples: `'loja_fisica'`.
-- MAGIC
-- MAGIC Onde ele entra? Sempre **depois do `FROM`** e **antes do `ORDER BY`**.

-- COMMAND ----------

SELECT
  id_venda,
  canal_venda,
  quantidade,
  preco_unitario,
  quantidade * preco_unitario AS receita
FROM ecommerce.bronze.vendas
WHERE canal_venda = 'loja_fisica'
ORDER BY receita DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Dá para combinar condições:
-- MAGIC
-- MAGIC - `AND`: as duas precisam ser verdadeiras;
-- MAGIC - `OR`: basta uma ser verdadeira.
-- MAGIC
-- MAGIC Vendas da loja física **com mais de uma unidade**:

-- COMMAND ----------

SELECT
  id_venda,
  canal_venda,
  quantidade,
  preco_unitario,
  quantidade * preco_unitario AS receita
FROM ecommerce.bronze.vendas
WHERE canal_venda = 'loja_fisica'
  AND quantidade > 1
ORDER BY receita DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Até aqui
-- MAGIC
-- MAGIC ```
-- MAGIC SELECT   colunas (e contas com AS)
-- MAGIC FROM     tabela
-- MAGIC WHERE    filtro de linhas
-- MAGIC ORDER BY ordenação
-- MAGIC LIMIT    quantas linhas
-- MAGIC ```
-- MAGIC
-- MAGIC A ordem de escrita é sempre essa. Se trocar, dá erro.
-- MAGIC
-- MAGIC ## Pergunta 05 · Quanto faturamos? Qual o ticket médio? (agregações)
-- MAGIC
-- MAGIC Até agora o resultado tinha **uma linha por venda**. O diretor não quer 3.020 linhas: ele quer **um número**. Para isso existem as funções de agregação, que resumem muitas linhas em uma:
-- MAGIC
-- MAGIC | Função | O que faz |
-- MAGIC |---|---|
-- MAGIC | `COUNT(*)` | Conta linhas |
-- MAGIC | `SUM(x)` | Soma |
-- MAGIC | `AVG(x)` | Média |
-- MAGIC | `MIN(x)` / `MAX(x)` | Menor e maior valor |
-- MAGIC
-- MAGIC Uma de cada vez. Primeiro: **quantas vendas** temos?

-- COMMAND ----------

SELECT COUNT(*) AS total_vendas
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Agora a **receita total**: a soma da receita de todas as vendas. Repare que dá para colocar a conta **dentro** do `SUM`.

-- COMMAND ----------

SELECT SUM(quantidade * preco_unitario) AS receita_total
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC O número veio com muitas casas decimais. `ROUND(valor, 2)` arredonda para 2 casas, como em reais.
-- MAGIC
-- MAGIC Agora juntamos tudo em um **painel de indicadores**. O **ticket médio** é a média da receita por venda:

-- COMMAND ----------

SELECT
  COUNT(*)                                    AS total_vendas,
  ROUND(SUM(quantidade * preco_unitario), 2)  AS receita_total,
  ROUND(AVG(quantidade * preco_unitario), 2)  AS ticket_medio,
  COUNT(DISTINCT id_cliente)                  AS clientes_unicos,
  MIN(data_venda)                             AS primeira_venda,
  MAX(data_venda)                             AS ultima_venda
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resposta ao Diretor Comercial:** R$ 974.077,28 em 3.020 vendas, com ticket médio de R$ 322,54, entre 13/12/2025 e 11/01/2026.
-- MAGIC
-- MAGIC > `COUNT(DISTINCT id_cliente)` conta **clientes diferentes**, e não vendas. Um cliente que comprou 60 vezes conta uma vez só.
-- MAGIC
-- MAGIC ## Pergunta 06 · Qual canal vende mais? (`GROUP BY`)
-- MAGIC
-- MAGIC A pergunta agora é "quanto **por canal**". Precisamos da mesma conta, mas **separada por grupo**.
-- MAGIC
-- MAGIC Primeiro, veja quais canais existem. `DISTINCT` remove as repetições:

-- COMMAND ----------

SELECT DISTINCT canal_venda
FROM ecommerce.bronze.vendas;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Dois canais. O `GROUP BY` junta as linhas de cada canal em um grupo e aplica a agregação **dentro de cada grupo**.
-- MAGIC
-- MAGIC Comece só contando as vendas de cada canal:

-- COMMAND ----------

SELECT
  canal_venda,
  COUNT(*) AS total_vendas
FROM ecommerce.bronze.vendas
GROUP BY canal_venda;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Agora acrescente a receita e o ticket médio, e ordene pela receita:

-- COMMAND ----------

SELECT
  canal_venda,
  COUNT(*)                                   AS total_vendas,
  ROUND(SUM(quantidade * preco_unitario), 2) AS receita_total,
  ROUND(AVG(quantidade * preco_unitario), 2) AS ticket_medio
FROM ecommerce.bronze.vendas
GROUP BY canal_venda
ORDER BY receita_total DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resposta:** o e-commerce vende 2,5 vezes mais que a loja física (2.155 × 865 vendas).
-- MAGIC
-- MAGIC > **Regra de ouro do `GROUP BY`:** toda coluna do `SELECT` precisa estar no `GROUP BY` **ou** dentro de uma agregação. Teste: apague o `GROUP BY canal_venda` e rode. O erro `MISSING_AGGREGATION` é o banco dizendo "você pediu o canal, mas não disse como agrupar".
-- MAGIC
-- MAGIC ### Receita por dia
-- MAGIC
-- MAGIC Mesma ideia, agrupando por dia. `DATE(data_venda)` corta o horário e deixa só a data. Depois de rodar, clique em **+ → Visualization** no resultado e escolha **Line** para ver o gráfico.

-- COMMAND ----------

SELECT
  DATE(data_venda)                           AS dia,
  COUNT(*)                                   AS total_vendas,
  ROUND(SUM(quantidade * preco_unitario), 2) AS receita_total
FROM ecommerce.bronze.vendas
GROUP BY DATE(data_venda)
ORDER BY dia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 07 · Qual categoria vende mais? (`JOIN`)
-- MAGIC
-- MAGIC Problema: a tabela `vendas` só tem o **código** do produto. A categoria está em outra tabela, `produtos`.
-- MAGIC
-- MAGIC Veja na prática. Esta é a primeira venda do arquivo:

-- COMMAND ----------

SELECT id_venda, id_produto, quantidade, preco_unitario
FROM ecommerce.bronze.vendas
WHERE id_venda = 'sal_adff6978b0c6';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Ela vendeu o produto `prd_96fbc500aec1`. Que produto é esse? Precisamos procurar na outra tabela:

-- COMMAND ----------

SELECT id_produto, nome_produto, categoria, marca
FROM ecommerce.bronze.produtos
WHERE id_produto = 'prd_96fbc500aec1';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Um Edredom Casal, da categoria Casa. Fazer isso na mão para 3.020 vendas é impossível. O `JOIN` faz essa busca para **todas** as linhas de uma vez:
-- MAGIC
-- MAGIC ```
-- MAGIC vendas.id_produto  ══ ponte ══  produtos.id_produto
-- MAGIC ```
-- MAGIC
-- MAGIC Três novidades na consulta:
-- MAGIC
-- MAGIC 1. `JOIN ecommerce.bronze.produtos p`: qual tabela juntar. O `p` é um **apelido** (alias) para não escrever o nome inteiro.
-- MAGIC 2. `ON v.id_produto = p.id_produto`: **a ponte**, a coluna que as duas tabelas têm em comum.
-- MAGIC 3. `v.coluna` e `p.coluna`: de qual tabela vem cada coluna.

-- COMMAND ----------

SELECT
  v.id_venda,
  v.id_produto,
  p.nome_produto,
  p.categoria
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.produtos p
  ON v.id_produto = p.id_produto
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Agora cada venda tem o nome e a categoria do produto. A partir daqui, é o que você já sabe: `GROUP BY` pela categoria e soma da receita.

-- COMMAND ----------

SELECT
  p.categoria,
  COUNT(*)                                       AS total_vendas,
  ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.produtos p
  ON v.id_produto = p.id_produto
GROUP BY p.categoria
ORDER BY receita_total DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resposta:** Moda lidera, seguida de Áudio e Acessórios.
-- MAGIC
-- MAGIC E os **10 produtos com mais receita**? É só trocar a categoria pelo nome do produto e colocar o `LIMIT`:

-- COMMAND ----------

SELECT
  p.nome_produto,
  p.categoria,
  SUM(v.quantidade)                              AS itens_vendidos,
  ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.produtos p
  ON v.id_produto = p.id_produto
GROUP BY p.nome_produto, p.categoria
ORDER BY receita_total DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pergunta 08 · Existe venda de produto fora do catálogo? (`LEFT JOIN`)
-- MAGIC
-- MAGIC Uma conferência que todo analista deveria fazer: a receita **com** `JOIN` bate com a receita **sem** `JOIN`?

-- COMMAND ----------

SELECT 'sem JOIN' AS consulta, ROUND(SUM(quantidade * preco_unitario), 2) AS receita
FROM ecommerce.bronze.vendas
UNION ALL
SELECT 'com JOIN', ROUND(SUM(v.quantidade * v.preco_unitario), 2)
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.produtos p ON v.id_produto = p.id_produto;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Não bate! Sumiram R$ 4.240,01. (O `UNION ALL` só empilha o resultado de duas consultas, uma embaixo da outra.)
-- MAGIC
-- MAGIC O motivo: o `JOIN` que usamos é um **`INNER JOIN`**. Ele só mantém as linhas que encontraram par **nas duas** tabelas. Se uma venda aponta para um produto que não existe no catálogo, ela é descartada **em silêncio**.
-- MAGIC
-- MAGIC | Tipo | O que mantém |
-- MAGIC |---|---|
-- MAGIC | `JOIN` (ou `INNER JOIN`) | Só o que casa nas duas tabelas |
-- MAGIC | `LEFT JOIN` | **Tudo** da tabela da esquerda (`vendas`), com vazio (`NULL`) onde não achou o produto |
-- MAGIC
-- MAGIC Com `LEFT JOIN` e um filtro `IS NULL`, encontramos exatamente as vendas "órfãs":

-- COMMAND ----------

SELECT
  v.id_venda,
  v.id_produto,
  p.nome_produto,
  v.quantidade * v.preco_unitario AS receita
FROM ecommerce.bronze.vendas v
LEFT JOIN ecommerce.bronze.produtos p
  ON v.id_produto = p.id_produto
WHERE p.id_produto IS NULL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC São **20 vendas** de produtos que não estão cadastrados. Repare que `nome_produto` veio vazio (`NULL`): não havia produto para buscar.
-- MAGIC
-- MAGIC > Isso é um **problema de qualidade de dados**, e não de SQL. Ele volta na Aula 2 (a camada silver marca essas vendas) e na Aula 3 (um teste automático avisa se o problema crescer). Por enquanto, lembre: **sempre confira os totais depois de um `JOIN`.**
-- MAGIC
-- MAGIC ---
-- MAGIC # 3. Diretoria de Clientes
-- MAGIC
-- MAGIC > "Quem são nossos 10 melhores clientes? De quais estados eles são?"
-- MAGIC
-- MAGIC ## Pergunta 09 · Os 10 melhores clientes (`JOIN` + `GROUP BY`)
-- MAGIC
-- MAGIC Vamos em três passos, sem pressa.
-- MAGIC
-- MAGIC **Passo 1:** receita por cliente, usando só a tabela `vendas`. Você já sabe fazer isso:

-- COMMAND ----------

SELECT
  id_cliente,
  ROUND(SUM(quantidade * preco_unitario), 2) AS receita_total
FROM ecommerce.bronze.vendas
GROUP BY id_cliente
ORDER BY receita_total DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Funciona, mas a diretora não conhece o cliente `cus_2b1b3e2a1515`. Ela quer o **nome**.
-- MAGIC
-- MAGIC **Passo 2:** `JOIN` com `clientes` para trazer o nome. Repare que agora agrupamos pelo nome também (regra de ouro!):

-- COMMAND ----------

SELECT
  c.nome_cliente,
  ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.clientes c
  ON v.id_cliente = c.id_cliente
GROUP BY c.nome_cliente
ORDER BY receita_total DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Passo 3:** acrescente o estado, a quantidade de compras e o ticket médio.

-- COMMAND ----------

SELECT
  c.nome_cliente,
  c.estado,
  COUNT(*)                                       AS total_compras,
  ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total,
  ROUND(AVG(v.quantidade * v.preco_unitario), 2) AS ticket_medio
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.clientes c
  ON v.id_cliente = c.id_cliente
GROUP BY c.nome_cliente, c.estado
ORDER BY receita_total DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resposta:** Ana Sophia Pereira (MG) lidera com R$ 30.716,63.
-- MAGIC
-- MAGIC ### E por estado?
-- MAGIC
-- MAGIC Para planejar a equipe regional, a diretora quer ver **clientes e receita por estado**. É a mesma consulta, agrupando pelo estado em vez do cliente:

-- COMMAND ----------

SELECT
  c.estado,
  COUNT(DISTINCT c.id_cliente)                   AS clientes,
  ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.clientes c
  ON v.id_cliente = c.id_cliente
GROUP BY c.estado
ORDER BY receita_total DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC > **Sua vez:** qual é o **ticket médio** de cada estado? Acrescente `ROUND(AVG(v.quantidade * v.preco_unitario), 2) AS ticket_medio` na consulta acima.
-- MAGIC
-- MAGIC ---
-- MAGIC # 4. Diretoria de Pricing
-- MAGIC
-- MAGIC > "Estamos mais caros que a concorrência? Quais produtos estão mais caros que **todos** os concorrentes?"
-- MAGIC
-- MAGIC ## Pergunta 10 · Estamos mais caros que o mercado? (`AVG`, `MIN`, `MAX`)
-- MAGIC
-- MAGIC A tabela `preco_competidores` tem uma linha por **produto × concorrente**. Olhe um produto só, o Tênis Puma Speedcat:

-- COMMAND ----------

SELECT id_produto, nome_concorrente, preco_concorrente
FROM ecommerce.bronze.preco_competidores
WHERE id_produto = 'prd_1317c4a1f775';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Quatro concorrentes, todos cobrando R$ 225,95. E nós? O `JOIN` com `produtos` coloca o **nosso preço** ao lado:

-- COMMAND ----------

SELECT
  p.nome_produto,
  p.preco_atual AS nosso_preco,
  pc.nome_concorrente,
  pc.preco_concorrente
FROM ecommerce.bronze.produtos p
JOIN ecommerce.bronze.preco_competidores pc
  ON p.id_produto = pc.id_produto
WHERE p.id_produto = 'prd_1317c4a1f775';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Cobramos R$ 451,90, o **dobro** da concorrência. Agora queremos isso para **todos** os produtos, em **uma linha por produto**. É um `GROUP BY` pelo produto, com três agregações sobre o preço dos concorrentes:

-- COMMAND ----------

SELECT
  p.nome_produto,
  p.categoria,
  p.preco_atual                        AS nosso_preco,
  ROUND(AVG(pc.preco_concorrente), 2)  AS preco_medio_concorrentes,
  MIN(pc.preco_concorrente)            AS menor_preco_concorrente,
  MAX(pc.preco_concorrente)            AS maior_preco_concorrente
FROM ecommerce.bronze.produtos p
JOIN ecommerce.bronze.preco_competidores pc
  ON p.id_produto = pc.id_produto
GROUP BY p.nome_produto, p.categoria, p.preco_atual;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Falta a pergunta principal: **quanto** estamos acima ou abaixo? A diferença percentual é:
-- MAGIC
-- MAGIC ```
-- MAGIC (nosso preço − preço médio dos concorrentes) ÷ preço médio × 100
-- MAGIC ```
-- MAGIC
-- MAGIC Positivo = **estamos mais caros**. Ordenamos do mais caro para o mais barato:

-- COMMAND ----------

SELECT
  p.nome_produto,
  p.categoria,
  p.preco_atual                        AS nosso_preco,
  ROUND(AVG(pc.preco_concorrente), 2)  AS preco_medio_concorrentes,
  ROUND((p.preco_atual - AVG(pc.preco_concorrente)) / AVG(pc.preco_concorrente) * 100, 1) AS diferenca_pct
FROM ecommerce.bronze.produtos p
JOIN ecommerce.bronze.preco_competidores pc
  ON p.id_produto = pc.id_produto
GROUP BY p.nome_produto, p.categoria, p.preco_atual
ORDER BY diferenca_pct DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Muitos tênis no topo. Vamos confirmar **por categoria**: é o mesmo cálculo, agrupando pela categoria.

-- COMMAND ----------

SELECT
  p.categoria,
  COUNT(DISTINCT p.id_produto)                                                        AS produtos,
  ROUND(AVG((p.preco_atual - pc.preco_concorrente) / pc.preco_concorrente * 100), 1) AS diferenca_pct_media
FROM ecommerce.bronze.produtos p
JOIN ecommerce.bronze.preco_competidores pc
  ON p.id_produto = pc.id_produto
GROUP BY p.categoria
ORDER BY diferenca_pct_media DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resposta:** a categoria **Tênis** está 100% acima do mercado. As outras estão praticamente no preço dos concorrentes.
-- MAGIC
-- MAGIC ## Pergunta 11 · Mais caros que **todos** os concorrentes (`HAVING`)
-- MAGIC
-- MAGIC Queremos só os produtos em que o nosso preço é maior que o **maior** preço entre os concorrentes. A condição seria `p.preco_atual > MAX(pc.preco_concorrente)`.
-- MAGIC
-- MAGIC Mas atenção: o `WHERE` **não aceita** agregações como `MAX`. Ele filtra as linhas **antes** de agrupar, quando o `MAX` ainda nem existe.
-- MAGIC
-- MAGIC | | Filtra | Quando |
-- MAGIC |---|---|---|
-- MAGIC | `WHERE` | linhas | **antes** do `GROUP BY` |
-- MAGIC | `HAVING` | grupos | **depois** do `GROUP BY` |
-- MAGIC
-- MAGIC Por isso usamos o `HAVING`, que vem logo depois do `GROUP BY`:

-- COMMAND ----------

SELECT
  p.nome_produto,
  p.categoria,
  p.preco_atual                  AS nosso_preco,
  MAX(pc.preco_concorrente)      AS maior_preco_concorrente,
  COUNT(pc.nome_concorrente)     AS concorrentes_monitorados
FROM ecommerce.bronze.produtos p
JOIN ecommerce.bronze.preco_competidores pc
  ON p.id_produto = pc.id_produto
GROUP BY p.nome_produto, p.categoria, p.preco_atual
HAVING p.preco_atual > MAX(pc.preco_concorrente)
ORDER BY p.categoria, nosso_preco DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resposta:** 35 produtos estão mais caros que todos os concorrentes, e a maioria é da categoria Tênis. O Diretor de Pricing já tem por onde começar.
-- MAGIC
-- MAGIC > **Sua vez:** coloque `WHERE p.preco_atual > MAX(pc.preco_concorrente)` no lugar do `HAVING` e rode. Leia o erro: agora ele faz sentido.
-- MAGIC
-- MAGIC ### A consulta completa, peça por peça
-- MAGIC
-- MAGIC ```
-- MAGIC SELECT   colunas e contas            ← o que mostrar
-- MAGIC FROM     tabela
-- MAGIC JOIN     outra tabela ON ponte       ← juntar tabelas
-- MAGIC WHERE    filtro de linhas            ← antes de agrupar
-- MAGIC GROUP BY agrupamento                 ← uma linha por grupo
-- MAGIC HAVING   filtro de grupos            ← depois de agrupar
-- MAGIC ORDER BY ordenação
-- MAGIC LIMIT    quantas linhas
-- MAGIC ```
-- MAGIC
-- MAGIC ---
-- MAGIC # 5. Dashboard: uma página por diretoria
-- MAGIC
-- MAGIC As respostas já existem. Falta colocá-las onde os diretores enxergam sem abrir um notebook.
-- MAGIC
-- MAGIC **Opção A: importar o dashboard pronto (2 min)**
-- MAGIC 1. Baixe `aula-01-sql-dashboard/dashboard/diretoria_ecommerce.lvdash.json` do repositório.
-- MAGIC 2. Menu lateral **Dashboards → seta ao lado de Create dashboard → Import dashboard from file**.
-- MAGIC 3. Selecione o arquivo e clique em **Publish**.
-- MAGIC
-- MAGIC **Opção B: montar do zero (15 min, recomendado na aula ao vivo)**
-- MAGIC 1. **Dashboards → Create dashboard**. Renomeie para *Diretoria E-commerce*.
-- MAGIC 2. Aba **Data → Create from SQL**: cole as consultas finais das perguntas 05 a 11 (uma por dataset). O passo a passo completo está no `README.md` desta pasta.
-- MAGIC 3. Aba do canvas: crie **3 páginas** (Vendas, Clientes e Pricing) e adicione os gráficos.
-- MAGIC 4. **Publish** e compartilhe o link.
-- MAGIC
-- MAGIC > Na Aula 4, os diretores deixam de precisar do painel para perguntar: eles vão conversar com os dados pelo **Genie**.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC # Bônus (para praticar em casa)
-- MAGIC
-- MAGIC ### `CASE WHEN`: classificar é o "se / então / senão" do SQL
-- MAGIC
-- MAGIC Segmentação de clientes pela receita total. Esta é a mesma regra usada na camada gold da Aula 2.

-- COMMAND ----------

SELECT
  c.nome_cliente,
  ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total,
  CASE
    WHEN SUM(v.quantidade * v.preco_unitario) >= 22000 THEN 'VIP'
    WHEN SUM(v.quantidade * v.preco_unitario) >= 17000 THEN 'TOP_TIER'
    ELSE 'REGULAR'
  END AS segmento
FROM ecommerce.bronze.vendas v
JOIN ecommerce.bronze.clientes c
  ON v.id_cliente = c.id_cliente
GROUP BY c.nome_cliente
ORDER BY receita_total DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Window functions: comparar sem perder o detalhe
-- MAGIC
-- MAGIC `GROUP BY` junta as linhas. Uma window function **mantém** as linhas e adiciona um cálculo que olha para as outras.
-- MAGIC
-- MAGIC - `ROW_NUMBER()`: ranking
-- MAGIC - `PARTITION BY`: ranking que recomeça em cada grupo
-- MAGIC - `SUM() OVER ()`: total geral, útil para percentuais
-- MAGIC - `LAG()`: valor da linha anterior

-- COMMAND ----------

-- Top 3 produtos de cada categoria
SELECT *
FROM (
  SELECT
    p.categoria,
    p.nome_produto,
    ROUND(SUM(v.quantidade * v.preco_unitario), 2) AS receita_total,
    ROW_NUMBER() OVER (
      PARTITION BY p.categoria
      ORDER BY SUM(v.quantidade * v.preco_unitario) DESC
    ) AS ranking_na_categoria
  FROM ecommerce.bronze.vendas v
  JOIN ecommerce.bronze.produtos p
    ON v.id_produto = p.id_produto
  GROUP BY p.categoria, p.nome_produto
)
WHERE ranking_na_categoria <= 3
ORDER BY categoria, ranking_na_categoria;

-- COMMAND ----------

-- Percentual da receita por canal
SELECT
  canal_venda,
  ROUND(SUM(quantidade * preco_unitario), 2) AS receita_total,
  ROUND(SUM(quantidade * preco_unitario) * 100 / SUM(SUM(quantidade * preco_unitario)) OVER (), 1) AS pct_receita
FROM ecommerce.bronze.vendas
GROUP BY canal_venda;

-- COMMAND ----------

-- Receita de cada dia comparada com o dia anterior
SELECT
  dia,
  receita_total,
  LAG(receita_total) OVER (ORDER BY dia)                                              AS receita_dia_anterior,
  ROUND((receita_total - LAG(receita_total) OVER (ORDER BY dia)) * 100
        / LAG(receita_total) OVER (ORDER BY dia), 1)                                  AS variacao_pct
FROM (
  SELECT DATE(data_venda) AS dia, ROUND(SUM(quantidade * preco_unitario), 2) AS receita_total
  FROM ecommerce.bronze.vendas
  GROUP BY DATE(data_venda)
)
ORDER BY dia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC ## Recap do Dia 1
-- MAGIC
-- MAGIC - Você criou um catálogo, schemas e subiu 4 CSVs como tabelas Delta na bronze.
-- MAGIC - Viu que uma tabela recusa dado errado e guarda o histórico (`DESCRIBE HISTORY`, `RESTORE`).
-- MAGIC - Respondeu os 3 diretores com `SELECT`, `WHERE`, `GROUP BY`, `HAVING` e `JOIN`.
-- MAGIC - Encontrou um problema real de qualidade: vendas de produtos não cadastrados.
-- MAGIC - Publicou um dashboard com uma página por diretoria.
-- MAGIC
-- MAGIC **Amanhã:** você subiu os CSVs na mão. E quando chegar arquivo novo todo dia? Na Aula 2 vamos **automatizar a chegada do dado**.
