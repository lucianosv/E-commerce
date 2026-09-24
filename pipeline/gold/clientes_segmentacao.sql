-- Gold · segmentação de clientes (diretoria de Customer Success)
-- Grão: uma linha por cliente.
--
-- Regra definida com a diretora de CS:
--   VIP       a partir de R$ 22.000
--   TOP_TIER  de R$ 17.000 até R$ 21.999,99
--   REGULAR   abaixo de R$ 17.000
-- Os limites vieram da distribuição real (cerca de 20% VIP). Com os antigos R$ 10.000 e R$ 5.000,
-- 49 dos 50 clientes viravam VIP, e um segmento que contém todo mundo não ajuda ninguém.
--
-- O LEFT JOIN a partir de clientes mantém quem nunca comprou (receita zero), que é justamente
-- quem o time de CS precisa ativar.

CREATE OR REFRESH MATERIALIZED VIEW gold.clientes_segmentacao (
  id_cliente       STRING        COMMENT 'Identificador do cliente (prefixo cus_).',
  nome_cliente     STRING        COMMENT 'Nome do cliente, sem pronome de tratamento.',
  estado           STRING        COMMENT 'Sigla da UF do cliente, por exemplo SP, RJ, MG.',
  nome_estado      STRING        COMMENT 'Nome completo do estado (fonte: API do IBGE).',
  regiao           STRING        COMMENT 'Região do Brasil: Norte, Nordeste, Centro-Oeste, Sudeste ou Sul (fonte: API do IBGE).',
  total_compras    BIGINT        COMMENT 'Quantidade de compras do cliente no período.',
  receita          DECIMAL(20,2) COMMENT 'Receita total gerada pelo cliente no período, em reais (R$).',
  ticket_medio     DECIMAL(11,2) COMMENT 'Valor médio por compra do cliente, em reais (R$).',
  primeira_compra  DATE          COMMENT 'Data da primeira compra do cliente.',
  ultima_compra    DATE          COMMENT 'Data da compra mais recente do cliente.',
  segmento_cliente STRING        COMMENT 'Segmento pela receita no período: VIP (a partir de R$ 22.000), TOP_TIER (R$ 17.000 a R$ 21.999,99) ou REGULAR (abaixo de R$ 17.000).',
  ranking_receita  INT           COMMENT 'Posição do cliente no ranking de receita (1 = cliente que mais gerou receita).'
)
COMMENT 'Uma linha por cliente com receita, compras, ticket médio, região e segmento. Use para perguntas sobre melhores clientes, clientes VIP, segmentos, estados e regiões.'
AS
WITH receita_por_cliente AS (
  SELECT
    c.id_cliente,
    c.nome_cliente,
    c.estado,
    c.nome_estado,
    c.regiao,
    COUNT(v.id_venda)           AS total_compras,
    COALESCE(SUM(v.receita), 0) AS receita,
    ROUND(AVG(v.receita), 2)    AS ticket_medio,
    MIN(v.data)                 AS primeira_compra,
    MAX(v.data)                 AS ultima_compra
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
  END                                       AS segmento_cliente,
  ROW_NUMBER() OVER (ORDER BY receita DESC) AS ranking_receita
FROM receita_por_cliente;
