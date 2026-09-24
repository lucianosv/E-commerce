-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Aula 4 · Preparar o dado para a IA
-- MAGIC ### "Todo mundo quer IA. Ninguém tem o dado organizado."
-- MAGIC
-- MAGIC O Genie lê o **nome** e o **comentário** de cada tabela e coluna para decidir qual SQL escrever. Uma coluna chamada `receita` sem comentário obriga o Genie a adivinhar: é bruta ou líquida? Inclui frete? Em reais?
-- MAGIC
-- MAGIC Este notebook documenta as 4 tabelas gold. É o trabalho menos glamoroso da imersão, e é o que faz o Genie acertar.
-- MAGIC
-- MAGIC > Este notebook também roda como **última tarefa do Job diário**: como a gold é recriada todo dia (`CREATE OR REPLACE`), os comentários precisam ser reaplicados depois dela.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC dbutils.widgets.text("catalogo", "ecommerce")

-- COMMAND ----------

USE CATALOG IDENTIFIER(:catalogo);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Antes: o que o Genie enxerga hoje
-- MAGIC
-- MAGIC Veja a coluna `comment`: vazia. É com isso que a IA teria de trabalhar.

-- COMMAND ----------

DESCRIBE TABLE gold.clientes_segmentacao;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Vendas: `gold.vendas_temporais`

-- COMMAND ----------

COMMENT ON TABLE gold.vendas_temporais IS
  'Vendas agregadas por dia, hora e canal. Use para perguntas de receita, número de vendas e ticket médio ao longo do tempo, por dia da semana, por hora ou por canal. Inclui todas as vendas, mesmo de produtos não cadastrados. Período dos dados: 13/12/2025 a 11/01/2026.';

ALTER TABLE gold.vendas_temporais ALTER COLUMN data           COMMENT 'Data da venda (sem horário).';
ALTER TABLE gold.vendas_temporais ALTER COLUMN dia_semana     COMMENT 'Dia da semana em português: Domingo, Segunda, Terça, Quarta, Quinta, Sexta, Sábado.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN dia_semana_num COMMENT 'Número do dia da semana para ordenação: 1 = Domingo ... 7 = Sábado.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN hora           COMMENT 'Hora do dia da venda, de 0 a 23.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN canal_venda    COMMENT 'Canal da venda: ecommerce (site) ou loja_fisica.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN total_vendas   COMMENT 'Quantidade de vendas (pedidos). Somar para totalizar.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN itens_vendidos COMMENT 'Quantidade de unidades vendidas. Somar para totalizar.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN receita        COMMENT 'Receita bruta em reais (R$) = quantidade × preço unitário. Somar para totalizar.';
ALTER TABLE gold.vendas_temporais ALTER COLUMN clientes_unicos COMMENT 'Clientes distintos NAQUELA linha (dia, hora, canal). Não somar entre linhas: para clientes únicos no período use gold.clientes_segmentacao.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Vendas: `gold.vendas_produtos`

-- COMMAND ----------

COMMENT ON TABLE gold.vendas_produtos IS
  'Desempenho de vendas por produto no período: receita, itens vendidos, ticket médio e rankings. Use para "produtos mais vendidos", "receita por categoria" e "receita por marca". Vendas de produtos fora do catálogo aparecem com nome "Produto não cadastrado".';

ALTER TABLE gold.vendas_produtos ALTER COLUMN id_produto           COMMENT 'Identificador do produto (prefixo prd_).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN nome_produto         COMMENT 'Nome do produto. Atenção: produtos diferentes podem ter o mesmo nome; use id_produto para contar produtos.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN categoria            COMMENT 'Categoria do produto, por exemplo Eletrônicos, Casa, Cozinha, Tênis, Áudio, Games.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN marca                COMMENT 'Marca do produto.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN faixa_preco          COMMENT 'Faixa de preço do produto: PREMIUM (acima de R$ 1.000), MEDIO (R$ 500,01 a R$ 1.000) ou BASICO (até R$ 500).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN produto_cadastrado   COMMENT 'false quando a venda é de um produto que não existe no catálogo (problema de qualidade de dados).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN total_vendas         COMMENT 'Quantidade de vendas (pedidos) do produto.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN itens_vendidos       COMMENT 'Unidades vendidas do produto.';
ALTER TABLE gold.vendas_produtos ALTER COLUMN receita              COMMENT 'Receita bruta do produto em reais (R$).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN ticket_medio         COMMENT 'Receita média por venda do produto, em reais (R$).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN ranking_receita      COMMENT 'Posição do produto no ranking geral de receita (1 = maior receita).';
ALTER TABLE gold.vendas_produtos ALTER COLUMN ranking_na_categoria COMMENT 'Posição do produto no ranking de receita dentro da própria categoria (1 = maior).';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Clientes: `gold.clientes_segmentacao`

-- COMMAND ----------

COMMENT ON TABLE gold.clientes_segmentacao IS
  'Uma linha por cliente com receita, compras, ticket médio, região e segmento. Use para perguntas sobre melhores clientes, clientes VIP, segmentos, estados e regiões.';

ALTER TABLE gold.clientes_segmentacao ALTER COLUMN id_cliente       COMMENT 'Identificador do cliente (prefixo cus_).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN nome_cliente     COMMENT 'Nome do cliente.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN estado           COMMENT 'Sigla da UF do cliente, por exemplo SP, RJ, MG.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN nome_estado      COMMENT 'Nome completo do estado (fonte: API do IBGE).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN regiao           COMMENT 'Região do Brasil: Norte, Nordeste, Centro-Oeste, Sudeste ou Sul (fonte: API do IBGE).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN total_compras    COMMENT 'Quantidade de compras do cliente no período.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN receita          COMMENT 'Receita total gerada pelo cliente no período, em reais (R$).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN ticket_medio     COMMENT 'Valor médio por compra do cliente, em reais (R$).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN primeira_compra  COMMENT 'Data da primeira compra do cliente.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN ultima_compra    COMMENT 'Data da compra mais recente do cliente.';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN segmento_cliente COMMENT 'Segmento pela receita no período: VIP (a partir de R$ 22.000), TOP_TIER (R$ 17.000 a R$ 21.999,99) ou REGULAR (abaixo de R$ 17.000).';
ALTER TABLE gold.clientes_segmentacao ALTER COLUMN ranking_receita  COMMENT 'Posição do cliente no ranking de receita (1 = cliente que mais gerou receita).';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Pricing: `gold.precos_competitividade`

-- COMMAND ----------

COMMENT ON TABLE gold.precos_competitividade IS
  'Nosso preço comparado ao de 4 concorrentes (Mercado Livre, Amazon, Magalu e Shopee), uma linha por produto monitorado. Use para perguntas de competitividade, produtos caros ou baratos em relação ao mercado.';

ALTER TABLE gold.precos_competitividade ALTER COLUMN id_produto                COMMENT 'Identificador do produto (prefixo prd_).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN nome_produto              COMMENT 'Nome do produto.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN categoria                 COMMENT 'Categoria do produto.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN marca                     COMMENT 'Marca do produto.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN nosso_preco               COMMENT 'Nosso preço atual de venda, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN preco_medio_concorrentes  COMMENT 'Média dos preços dos concorrentes para o produto, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN preco_minimo_concorrentes COMMENT 'Menor preço entre os concorrentes, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN preco_maximo_concorrentes COMMENT 'Maior preço entre os concorrentes, em reais (R$).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN total_concorrentes        COMMENT 'Quantos concorrentes têm preço coletado para o produto (1 a 4).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN diferenca_pct_vs_media    COMMENT 'Diferença percentual do nosso preço contra a média dos concorrentes, em pontos percentuais (10 = 10% mais caro; -5 = 5% mais barato).';
ALTER TABLE gold.precos_competitividade ALTER COLUMN diferenca_pct_vs_minimo   COMMENT 'Diferença percentual do nosso preço contra o concorrente mais barato, em pontos percentuais.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN classificacao_preco       COMMENT 'Posição de preço: MAIS_CARO_QUE_TODOS, ACIMA_DA_MEDIA, NA_MEDIA, ABAIXO_DA_MEDIA ou MAIS_BARATO_QUE_TODOS.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN receita                   COMMENT 'Receita do produto no período, em reais (R$). Zero se nunca vendeu.';
ALTER TABLE gold.precos_competitividade ALTER COLUMN itens_vendidos            COMMENT 'Unidades vendidas do produto no período.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Depois: o mesmo `DESCRIBE`, agora com contexto

-- COMMAND ----------

DESCRIBE TABLE gold.clientes_segmentacao;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Próximo passo:** criar o Genie space (veja o `README.md` desta pasta). As instruções, as perguntas de exemplo e o SQL de referência estão em `genie/diretoria_ecommerce.geniespace.json`.
