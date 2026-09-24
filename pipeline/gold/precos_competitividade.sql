-- Gold · competitividade de preço (diretoria de Pricing)
-- Grão: uma linha por produto com preço de concorrente.
--
-- diferenca_pct_vs_media positiva = estamos mais caros.
--
-- possui_preco_suspeito: algum concorrente cobra menos de 60% do nosso preço (marcado na silver).
-- O produto continua na conta, porque promoção relâmpago existe, mas o time de Pricing precisa
-- confirmar o preço antes de reagir a ele.

CREATE OR REFRESH MATERIALIZED VIEW gold.precos_competitividade (
  id_produto                STRING        COMMENT 'Identificador do produto (prefixo prd_).',
  nome_produto              STRING        COMMENT 'Nome do produto.',
  categoria                 STRING        COMMENT 'Categoria do produto.',
  marca                     STRING        COMMENT 'Marca do produto.',
  nosso_preco               DECIMAL(10,2) COMMENT 'Nosso preço atual de venda, em reais (R$).',
  preco_medio_concorrentes  DECIMAL(11,2) COMMENT 'Média dos preços dos concorrentes para o produto, em reais (R$).',
  preco_minimo_concorrentes DECIMAL(10,2) COMMENT 'Menor preço entre os concorrentes, em reais (R$).',
  preco_maximo_concorrentes DECIMAL(10,2) COMMENT 'Maior preço entre os concorrentes, em reais (R$).',
  total_concorrentes        BIGINT        COMMENT 'Quantos concorrentes têm preço coletado para o produto (1 a 4).',
  diferenca_pct_vs_media    DECIMAL(19,2) COMMENT 'Diferença percentual do nosso preço contra a média dos concorrentes, em pontos percentuais (10 = 10% mais caro; -5 = 5% mais barato).',
  diferenca_pct_vs_minimo   DECIMAL(18,2) COMMENT 'Diferença percentual do nosso preço contra o concorrente mais barato, em pontos percentuais.',
  classificacao_preco       STRING        COMMENT 'Posição de preço: MAIS_CARO_QUE_TODOS, ACIMA_DA_MEDIA, NA_MEDIA, ABAIXO_DA_MEDIA ou MAIS_BARATO_QUE_TODOS.',
  possui_preco_suspeito     BOOLEAN       COMMENT 'true quando algum concorrente cobra menos de 60% do nosso preço: possível erro de coleta ou promoção. Confirmar antes de agir.',
  receita                   DECIMAL(20,2) COMMENT 'Receita do produto no período, em reais (R$). Zero se nunca vendeu.',
  itens_vendidos            BIGINT        COMMENT 'Unidades vendidas do produto no período.'
)
COMMENT 'Nosso preço comparado ao de 4 concorrentes (Mercado Livre, Amazon, Magalu e Shopee), uma linha por produto monitorado. Use para perguntas de competitividade, produtos caros ou baratos em relação ao mercado. Período dos dados: 13/12/2025 a 11/01/2026.'
AS
WITH mercado AS (
  SELECT
    id_produto,
    ROUND(AVG(preco_concorrente), 2) AS preco_medio_concorrentes,
    MIN(preco_concorrente)           AS preco_minimo_concorrentes,
    MAX(preco_concorrente)           AS preco_maximo_concorrentes,
    COUNT(*)                         AS total_concorrentes,
    BOOL_OR(preco_suspeito)          AS possui_preco_suspeito
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
