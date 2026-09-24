-- Gold · desempenho por produto (diretoria Comercial)
-- Grão: uma linha por produto vendido.
--
-- ROW_NUMBER() numera os produtos pela receita, no geral e dentro de cada categoria.
-- Vendas sem cadastro aparecem como "Produto não cadastrado", para a soma bater com a série temporal.

CREATE OR REFRESH MATERIALIZED VIEW gold.vendas_produtos (
  id_produto           STRING        COMMENT 'Identificador do produto (prefixo prd_).',
  nome_produto         STRING        COMMENT 'Nome do produto. Atenção: produtos diferentes podem ter o mesmo nome; use id_produto para contar produtos.',
  categoria            STRING        COMMENT 'Categoria do produto, por exemplo Eletrônicos, Casa, Cozinha, Tênis, Áudio, Games.',
  marca                STRING        COMMENT 'Marca do produto.',
  faixa_preco          STRING        COMMENT 'Faixa de preço do produto: PREMIUM (acima de R$ 1.000), MEDIO (R$ 500,01 a R$ 1.000) ou BASICO (até R$ 500).',
  produto_cadastrado   BOOLEAN       COMMENT 'false quando a venda é de um produto que não existe no catálogo (problema de qualidade de dados).',
  total_vendas         BIGINT        COMMENT 'Quantidade de vendas (pedidos) do produto.',
  itens_vendidos       BIGINT        COMMENT 'Unidades vendidas do produto.',
  receita              DECIMAL(20,2) COMMENT 'Receita bruta do produto em reais (R$).',
  ticket_medio         DECIMAL(11,2) COMMENT 'Receita média por venda do produto, em reais (R$).',
  ranking_receita      INT           COMMENT 'Posição do produto no ranking geral de receita (1 = maior receita).',
  ranking_na_categoria INT           COMMENT 'Posição do produto no ranking de receita dentro da própria categoria (1 = maior).'
)
COMMENT 'Desempenho de vendas por produto no período: receita, itens vendidos, ticket médio e rankings. Use para "produtos mais vendidos", "receita por categoria" e "receita por marca". Vendas de produtos fora do catálogo aparecem com nome "Produto não cadastrado".'
AS
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
