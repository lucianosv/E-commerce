-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Aula 3 · Parte 2: Silver → Gold
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

ALTER TABLE gold.vendas_temporais ALTER COLUMN data COMMENT 'Data da venda (sem horário).';
ALTER TABLE gold.vendas_temporais ALTER COLUMN dia_semana COMMENT 'Dia da semana em português: Domingo, Segunda, Terça, Quarta, Quinta, Sexta, Sábado.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN dia_semana_num COMMENT 'Número do dia da semana para ordenação: 1 = Domingo ... 7 = Sábado.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN hora COMMENT 'Hora do dia da venda, de 0 a 23.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN canal_venda COMMENT 'Canal da venda: ecommerce (site) ou loja_fisica.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN total_vendas COMMENT 'Quantidade de vendas (pedidos). Somar para totalizar.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN itens_vendidos COMMENT 'Quantidade de unidades vendidas. Somar para totalizar.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN receita COMMENT 'Receita bruta em reais (R$) = quantidade × preço unitário. Somar para totalizar.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN clientes_unicos COMMENT 'Clientes distintos NAQUELA linha (dia, hora, canal). Não somar entre linhas: para clientes únicos no período use gold.clientes_segmentacao.';
COMMENT ON TABLE gold.vendas_temporais IS 'Vendas agregadas por dia, hora e canal. Use para perguntas de receita, número de vendas e ticket médio ao longo do tempo, por dia da semana, por hora ou por canal. Inclui todas as vendas, mesmo de produtos não cadastrados. Período dos dados: 13/12/2025 a 11/01/2026.';

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

ALTER TABLE gold.vendas_produtos ALTER COLUMN id_produto COMMENT 'Identificador do produto (prefixo prd_).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN nome_produto COMMENT 'Nome do produto. Atenção: produtos diferentes podem ter o mesmo nome; use id_produto para contar produtos.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN categoria COMMENT 'Categoria do produto, por exemplo Eletrônicos, Casa, Cozinha, Tênis, Áudio, Games.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN marca COMMENT 'Marca do produto.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN faixa_preco COMMENT 'Faixa de preço do produto: PREMIUM (acima de R$ 1.000), MEDIO (R$ 500,01 a R$ 1.000) ou BASICO (até R$ 500).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN produto_cadastrado COMMENT 'false quando a venda é de um produto que não existe no catálogo (problema de qualidade de dados).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN total_vendas COMMENT 'Quantidade de vendas (pedidos) do produto.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN itens_vendidos COMMENT 'Unidades vendidas do produto.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN receita COMMENT 'Receita bruta do produto em reais (R$).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN ticket_medio COMMENT 'Receita média por venda do produto, em reais (R$).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN ranking_receita COMMENT 'Posição do produto no ranking geral de receita (1 = maior receita).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN ranking_na_categoria COMMENT 'Posição do produto no ranking de receita dentro da própria categoria (1 = maior).';
COMMENT ON TABLE gold.vendas_produtos IS 'Desempenho de vendas por produto no período: receita, itens vendidos, ticket médio e rankings. Use para "produtos mais vendidos", "receita por categoria" e "receita por marca". Vendas de produtos fora do catálogo aparecem com nome "Produto não cadastrado". Período dos dados: 13/12/2025 a 11/01/2026.';

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

ALTER TABLE gold.clientes_segmentacao ALTER COLUMN id_cliente COMMENT 'Identificador do cliente (prefixo cus_).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN nome_cliente COMMENT 'Nome do cliente, sem pronome de tratamento.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN estado COMMENT 'Sigla da UF do cliente, por exemplo SP, RJ, MG.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN nome_estado COMMENT 'Nome completo do estado (fonte: API do IBGE).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN regiao COMMENT 'Região do Brasil: Norte, Nordeste, Centro-Oeste, Sudeste ou Sul (fonte: API do IBGE).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN total_compras COMMENT 'Quantidade de compras do cliente no período.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN receita COMMENT 'Receita total gerada pelo cliente no período, em reais (R$).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN ticket_medio COMMENT 'Valor médio por compra do cliente, em reais (R$).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN primeira_compra COMMENT 'Data da primeira compra do cliente.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN ultima_compra COMMENT 'Data da compra mais recente do cliente.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN segmento_cliente COMMENT 'Segmento pela receita no período: VIP (a partir de R$ 22.000), TOP_TIER (R$ 17.000 a R$ 21.999,99) ou REGULAR (abaixo de R$ 17.000).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN ranking_receita COMMENT 'Posição do cliente no ranking de receita (1 = cliente que mais gerou receita).';
COMMENT ON TABLE gold.clientes_segmentacao IS 'Uma linha por cliente com receita, compras, ticket médio, região e segmento. Use para perguntas sobre melhores clientes, clientes VIP, segmentos, estados e regiões.';

SELECT segmento_cliente, COUNT(*) AS clientes, SUM(receita) AS receita
FROM gold.clientes_segmentacao
GROUP BY segmento_cliente
ORDER BY receita DESC;

-- COMMAND ----------

-- DBTITLE 1,Vendas detalhadas
-- MAGIC %md
-- MAGIC ## Vendas: detalhadas (todas as diretorias)
-- MAGIC
-- MAGIC As outras golds são agregadas para responder rápido as perguntas de cada diretoria. Esta aqui junta tudo o que descreve uma venda (produto, cliente, região, segmento), para as perguntas que cruzam diretorias: "receita por região e categoria", "quanto os VIPs compram no site". O dashboard usa esta tabela nos filtros cruzados e o Genie a usa quando nenhuma agregada serve.

-- COMMAND ----------

-- DBTITLE 1,Criar gold.vendas_detalhadas
CREATE OR REPLACE TABLE gold.vendas_detalhadas
CLUSTER BY (data) AS
SELECT
  v.id_venda,
  v.data_venda,
  v.data,
  v.dia_semana,
  v.dia_semana_num,
  v.hora,
  v.canal_venda,
  v.id_produto,
  COALESCE(p.nome_produto, 'Produto não cadastrado') AS nome_produto,
  COALESCE(p.categoria, 'Não cadastrado')            AS categoria,
  COALESCE(p.marca, 'Não cadastrado')                AS marca,
  p.faixa_preco,
  v.id_cliente,
  c.nome_cliente,
  c.estado,
  c.regiao,
  c.segmento_cliente,
  v.quantidade,
  v.preco_unitario,
  v.receita,
  v.produto_cadastrado,
  v.venda_antes_do_cadastro
FROM silver.vendas v
LEFT JOIN silver.produtos p
  ON v.id_produto = p.id_produto
LEFT JOIN gold.clientes_segmentacao c
  ON v.id_cliente = c.id_cliente;

ALTER TABLE gold.vendas_detalhadas ALTER COLUMN id_venda COMMENT 'Identificador da venda (prefixo sal_). Uma linha por venda.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN data_venda COMMENT 'Data e hora da venda.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN data COMMENT 'Data da venda (sem horário).';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN dia_semana COMMENT 'Dia da semana em português: Domingo, Segunda, Terça, Quarta, Quinta, Sexta, Sábado.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN dia_semana_num COMMENT 'Número do dia da semana para ordenação: 1 = Domingo ... 7 = Sábado.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN hora COMMENT 'Hora do dia da venda, de 0 a 23.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN canal_venda COMMENT 'Canal da venda: ecommerce (site) ou loja_fisica.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN id_produto COMMENT 'Identificador do produto (prefixo prd_).';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN nome_produto COMMENT 'Nome do produto, ou "Produto não cadastrado". Produtos diferentes podem ter o mesmo nome; use id_produto para contar produtos.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN categoria COMMENT 'Categoria do produto, ou "Não cadastrado".';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN marca COMMENT 'Marca do produto, ou "Não cadastrado".';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN faixa_preco COMMENT 'Faixa de preço do produto: PREMIUM, MEDIO ou BASICO. Vazia para produto não cadastrado.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN id_cliente COMMENT 'Identificador do cliente (prefixo cus_).';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN nome_cliente COMMENT 'Nome do cliente, sem pronome de tratamento.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN estado COMMENT 'Sigla da UF do cliente, por exemplo SP, RJ, MG.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN regiao COMMENT 'Região do Brasil do cliente: Norte, Nordeste, Centro-Oeste, Sudeste ou Sul.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN segmento_cliente COMMENT 'Segmento do cliente no período: VIP, TOP_TIER ou REGULAR (mesma regra de gold.clientes_segmentacao).';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN quantidade COMMENT 'Unidades vendidas nesta venda.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN preco_unitario COMMENT 'Preço cobrado por unidade, em reais (R$).';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN receita COMMENT 'Receita bruta da venda em reais (R$) = quantidade × preço unitário. Somar para totalizar.';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN produto_cadastrado COMMENT 'false quando o produto vendido não existe no catálogo (problema de qualidade de dados).';
ALTER TABLE gold.vendas_detalhadas ALTER COLUMN venda_antes_do_cadastro COMMENT 'true quando a venda aconteceu antes da data de criação do produto (problema de qualidade de dados).';
COMMENT ON TABLE gold.vendas_detalhadas IS 'Uma linha por venda, com produto, cliente, região e segmento já juntos. Use para perguntas que cruzam dimensões, como receita por região e categoria, ou canal preferido de cada segmento. Inclui todas as vendas, mesmo de produtos não cadastrados. Período dos dados: 13/12/2025 a 11/01/2026.';

SELECT * FROM gold.vendas_detalhadas LIMIT 10;

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
  m.possui_preco_suspeito,
  COALESCE(v.receita, 0)                                                                    AS receita,
  COALESCE(v.itens_vendidos, 0)                                                             AS itens_vendidos
FROM silver.produtos p
JOIN mercado m
  ON p.id_produto = m.id_produto
LEFT JOIN vendas v
  ON p.id_produto = v.id_produto;

ALTER TABLE gold.precos_competitividade ALTER COLUMN id_produto COMMENT 'Identificador do produto (prefixo prd_).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN nome_produto COMMENT 'Nome do produto.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN categoria COMMENT 'Categoria do produto.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN marca COMMENT 'Marca do produto.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN nosso_preco COMMENT 'Nosso preço atual de venda, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN preco_medio_concorrentes COMMENT 'Média dos preços dos concorrentes para o produto, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN preco_minimo_concorrentes COMMENT 'Menor preço entre os concorrentes, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN preco_maximo_concorrentes COMMENT 'Maior preço entre os concorrentes, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN total_concorrentes COMMENT 'Quantos concorrentes têm preço coletado para o produto (1 a 4).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN diferenca_pct_vs_media COMMENT 'Diferença percentual do nosso preço contra a média dos concorrentes, em pontos percentuais (10 = 10% mais caro; -5 = 5% mais barato).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN diferenca_pct_vs_minimo COMMENT 'Diferença percentual do nosso preço contra o concorrente mais barato, em pontos percentuais.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN classificacao_preco COMMENT 'Posição de preço: MAIS_CARO_QUE_TODOS, ACIMA_DA_MEDIA, NA_MEDIA, ABAIXO_DA_MEDIA ou MAIS_BARATO_QUE_TODOS.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN possui_preco_suspeito COMMENT 'true quando algum concorrente cobra menos de 60% do nosso preço: possível erro de coleta ou promoção. Confirmar antes de agir.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN receita COMMENT 'Receita do produto no período, em reais (R$). Zero se nunca vendeu.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN itens_vendidos COMMENT 'Unidades vendidas do produto no período.';
COMMENT ON TABLE gold.precos_competitividade IS 'Nosso preço comparado ao de 4 concorrentes (Mercado Livre, Amazon, Magalu e Shopee), uma linha por produto monitorado. Use para perguntas de competitividade, produtos caros ou baratos em relação ao mercado. Período dos dados: 13/12/2025 a 11/01/2026.';

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
UNION ALL SELECT 'gold.clientes_segmentacao', SUM(receita) FROM gold.clientes_segmentacao
UNION ALL SELECT 'gold.vendas_detalhadas',    SUM(receita) FROM gold.vendas_detalhadas
UNION ALL SELECT 'gold.precos_competitividade', SUM(receita) FROM gold.precos_competitividade;