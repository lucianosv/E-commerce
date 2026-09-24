-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Aula 2 · Parte 3: Silver → Gold
-- MAGIC
-- MAGIC A gold é o dado **pronto para o negócio**: cada tabela responde as perguntas de uma diretoria, sem que ninguém precise lembrar de `JOIN`, de receita ou de produto não cadastrado.
-- MAGIC
-- MAGIC | Diretoria | Tabela gold | Grão (uma linha por...) |
-- MAGIC |---|---|---|
-- MAGIC | Vendas | `gold.vendas_temporais` | dia × hora × canal |
-- MAGIC | Vendas | `gold.vendas_produtos` | produto |
-- MAGIC | Clientes | `gold.clientes_segmentacao` | cliente |
-- MAGIC | Pricing | `gold.precos_competitividade` | produto com preço de concorrente |
-- MAGIC
-- MAGIC As regras ficam em SQL: são as mesmas consultas da Aula 1, agora salvas como tabela e recalculadas pelo Job todos os dias. Aqui entram também o `CASE WHEN` e as window functions que ficaram de bônus no Dia 1.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC dbutils.widgets.text("catalogo", "ecommerce")

-- COMMAND ----------

USE CATALOG IDENTIFIER(:catalogo);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Vendas: série temporal
-- MAGIC
-- MAGIC Responde "quanto vendemos por dia, por hora, por canal?". Inclui **todas** as vendas, inclusive as de produtos não cadastrados: dinheiro que entrou é receita.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.vendas_temporais AS
SELECT
  data,
  dia_semana,
  dia_semana_num,
  hora,
  canal_venda,
  COUNT(*)                   AS total_vendas,
  SUM(quantidade)            AS itens_vendidos,
  SUM(receita)               AS receita,
  COUNT(DISTINCT id_cliente) AS clientes_unicos
FROM silver.vendas
GROUP BY data, dia_semana, dia_semana_num, hora, canal_venda;

SELECT * FROM gold.vendas_temporais ORDER BY data DESC, hora DESC LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Vendas: desempenho por produto
-- MAGIC
-- MAGIC `ROW_NUMBER()` numera os produtos pela receita, no geral e dentro de cada categoria (`PARTITION BY`). Vendas sem cadastro aparecem agrupadas como "Produto não cadastrado", para a soma bater com a série temporal.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.vendas_produtos AS
WITH por_produto AS (
  SELECT
    v.id_produto,
    COALESCE(p.nome_produto, 'Produto não cadastrado') AS nome_produto,
    COALESCE(p.categoria, 'Não cadastrado')            AS categoria,
    COALESCE(p.marca, 'Não cadastrado')                AS marca,
    p.faixa_preco,
    v.produto_cadastrado,
    COUNT(*)                                           AS total_vendas,
    SUM(v.quantidade)                                  AS itens_vendidos,
    SUM(v.receita)                                     AS receita,
    ROUND(AVG(v.receita), 2)                           AS ticket_medio
  FROM silver.vendas v
  LEFT JOIN silver.produtos p
    ON v.id_produto = p.id_produto
  GROUP BY ALL
)
SELECT
  *,
  ROW_NUMBER() OVER (ORDER BY receita DESC)                        AS ranking_receita,
  ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY receita DESC) AS ranking_na_categoria
FROM por_produto;

SELECT * FROM gold.vendas_produtos ORDER BY ranking_receita LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Clientes: segmentação
-- MAGIC
-- MAGIC Regra definida com a Diretora de Customer Success:
-- MAGIC
-- MAGIC | Segmento | Receita no período |
-- MAGIC |---|---|
-- MAGIC | `VIP` | a partir de R$ 22.000 |
-- MAGIC | `TOP_TIER` | de R$ 17.000 até R$ 21.999,99 |
-- MAGIC | `REGULAR` | abaixo de R$ 17.000 |
-- MAGIC
-- MAGIC > O projeto antigo usava R$ 10.000 e R$ 5.000. Com esses limites, 49 dos 50 clientes viravam VIP, e um segmento que contém todo mundo não ajuda ninguém. Os novos limites vieram da distribuição real: cerca de 20% dos clientes são VIP. **Regra de segmentação é decisão de negócio, e deve ser validada com o dado.**
-- MAGIC
-- MAGIC O `LEFT JOIN` a partir de `clientes` mantém quem nunca comprou (receita zero), que é justamente quem o time de CS precisa ativar.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.clientes_segmentacao AS
WITH receita_por_cliente AS (
  SELECT
    c.id_cliente,
    c.nome_cliente,
    c.estado,
    c.nome_estado,
    c.regiao,
    COUNT(v.id_venda)                   AS total_compras,
    COALESCE(SUM(v.receita), 0)         AS receita,
    ROUND(AVG(v.receita), 2)            AS ticket_medio,
    MIN(v.data)                         AS primeira_compra,
    MAX(v.data)                         AS ultima_compra
  FROM silver.clientes c
  LEFT JOIN silver.vendas v
    ON c.id_cliente = v.id_cliente
  GROUP BY ALL
)
SELECT
  *,
  CASE
    WHEN receita >= 22000 THEN 'VIP'
    WHEN receita >= 17000 THEN 'TOP_TIER'
    ELSE 'REGULAR'
  END                                         AS segmento_cliente,
  ROW_NUMBER() OVER (ORDER BY receita DESC)   AS ranking_receita
FROM receita_por_cliente;

SELECT segmento_cliente, COUNT(*) AS clientes, SUM(receita) AS receita
FROM gold.clientes_segmentacao
GROUP BY segmento_cliente
ORDER BY receita DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pricing: competitividade
-- MAGIC
-- MAGIC Para cada produto com preço de concorrente: nosso preço, média, mínimo e máximo do mercado, a diferença percentual e uma classificação.
-- MAGIC
-- MAGIC `diferenca_pct_vs_media` positiva = **estamos mais caros**.

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.precos_competitividade AS
WITH mercado AS (
  SELECT
    id_produto,
    ROUND(AVG(preco_concorrente), 2) AS preco_medio_concorrentes,
    MIN(preco_concorrente)           AS preco_minimo_concorrentes,
    MAX(preco_concorrente)           AS preco_maximo_concorrentes,
    COUNT(*)                         AS total_concorrentes
  FROM silver.preco_competidores
  GROUP BY id_produto
),
vendas AS (
  SELECT id_produto, SUM(receita) AS receita, SUM(quantidade) AS itens_vendidos
  FROM silver.vendas
  GROUP BY id_produto
)
SELECT
  p.id_produto,
  p.nome_produto,
  p.categoria,
  p.marca,
  p.preco_atual                                                                             AS nosso_preco,
  m.preco_medio_concorrentes,
  m.preco_minimo_concorrentes,
  m.preco_maximo_concorrentes,
  m.total_concorrentes,
  ROUND((p.preco_atual - m.preco_medio_concorrentes) / m.preco_medio_concorrentes * 100, 2)   AS diferenca_pct_vs_media,
  ROUND((p.preco_atual - m.preco_minimo_concorrentes) / m.preco_minimo_concorrentes * 100, 2) AS diferenca_pct_vs_minimo,
  CASE
    WHEN p.preco_atual > m.preco_maximo_concorrentes THEN 'MAIS_CARO_QUE_TODOS'
    WHEN p.preco_atual < m.preco_minimo_concorrentes THEN 'MAIS_BARATO_QUE_TODOS'
    WHEN p.preco_atual > m.preco_medio_concorrentes  THEN 'ACIMA_DA_MEDIA'
    WHEN p.preco_atual < m.preco_medio_concorrentes  THEN 'ABAIXO_DA_MEDIA'
    ELSE 'NA_MEDIA'
  END                                                                                       AS classificacao_preco,
  COALESCE(v.receita, 0)                                                                    AS receita,
  COALESCE(v.itens_vendidos, 0)                                                             AS itens_vendidos
FROM silver.produtos p
JOIN mercado m
  ON p.id_produto = m.id_produto
LEFT JOIN vendas v
  ON p.id_produto = v.id_produto;

SELECT classificacao_preco, COUNT(*) AS produtos
FROM gold.precos_competitividade
GROUP BY classificacao_preco
ORDER BY produtos DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Conferência final
-- MAGIC
-- MAGIC A receita total precisa ser a mesma em todas as visões. Se não bater, alguma regra está perdendo ou duplicando venda.

-- COMMAND ----------

SELECT 'silver.vendas' AS origem, SUM(receita) AS receita FROM silver.vendas
UNION ALL SELECT 'gold.vendas_temporais',     SUM(receita) FROM gold.vendas_temporais
UNION ALL SELECT 'gold.vendas_produtos',      SUM(receita) FROM gold.vendas_produtos
UNION ALL SELECT 'gold.clientes_segmentacao', SUM(receita) FROM gold.clientes_segmentacao;
