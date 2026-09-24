-- Gold · qualidade dos dados (todas as diretorias)
-- Grão: uma linha por regra de qualidade.
--
-- As expectations da silver medem os problemas a cada execução, mas essas métricas ficam no
-- event log do pipeline, que o diretor não abre. Esta tabela leva o mesmo placar para o
-- dashboard e para o Genie: "quanto da receita tem problema de cadastro?".
--
-- Severidade:
--   ALERTA       problema real que alguém precisa resolver na origem
--   INFORMATIVO  característica do dado que muda a leitura dos números
--   CORRIGIDO    a silver já trata; a linha registra quantas vezes aconteceu

CREATE OR REFRESH MATERIALIZED VIEW gold.qualidade_dados (
  regra           STRING        COMMENT 'Descrição da regra de qualidade verificada.',
  tabela          STRING        COMMENT 'Tabela silver onde a regra é verificada.',
  severidade      STRING        COMMENT 'ALERTA (resolver na origem), INFORMATIVO (muda a leitura dos números) ou CORRIGIDO (a silver já trata).',
  linhas_afetadas BIGINT        COMMENT 'Quantidade de linhas da tabela que caem na regra.',
  receita_afetada DECIMAL(20,2) COMMENT 'Receita em reais (R$) das vendas afetadas. Vazia quando a regra não envolve vendas.'
)
COMMENT 'Placar de qualidade dos dados: uma linha por regra, com quantas linhas e quanta receita cada problema afeta. Use para perguntas sobre confiabilidade dos números, vendas de produtos não cadastrados e preços suspeitos de concorrentes.'
AS
SELECT
  'Venda de produto não cadastrado' AS regra,
  'silver.vendas'                   AS tabela,
  'ALERTA'                          AS severidade,
  COUNT(*)                          AS linhas_afetadas,
  SUM(receita)                      AS receita_afetada
FROM silver.vendas
WHERE NOT produto_cadastrado

UNION ALL

SELECT 'Venda anterior à criação do produto', 'silver.vendas', 'ALERTA', COUNT(*), SUM(receita)
FROM silver.vendas
WHERE venda_antes_do_cadastro

UNION ALL

SELECT 'Preço de concorrente abaixo de 60% do nosso', 'silver.preco_competidores', 'ALERTA', COUNT(*), CAST(NULL AS DECIMAL(20,2))
FROM silver.preco_competidores
WHERE preco_suspeito

UNION ALL

SELECT 'Marca do produto diferente da marca citada no nome', 'silver.produtos', 'ALERTA', COUNT(*), CAST(NULL AS DECIMAL(20,2))
FROM silver.produtos p
WHERE EXISTS (
  SELECT 1
  FROM (SELECT DISTINCT marca FROM silver.produtos) m
  WHERE m.marca <> p.marca
    AND lower(p.nome_produto) LIKE '%' || lower(m.marca) || '%'
)

UNION ALL

SELECT 'Produto com nome igual ao de outro produto', 'silver.produtos', 'INFORMATIVO', COUNT(*), CAST(NULL AS DECIMAL(20,2))
FROM (
  SELECT nome_produto, COUNT(*) OVER (PARTITION BY nome_produto) AS mesmo_nome
  FROM silver.produtos
)
WHERE mesmo_nome > 1

UNION ALL

SELECT 'Produto monitorado em menos de 4 concorrentes', 'silver.preco_competidores', 'INFORMATIVO', COUNT(*), CAST(NULL AS DECIMAL(20,2))
FROM (
  SELECT id_produto
  FROM silver.preco_competidores
  GROUP BY id_produto
  HAVING COUNT(*) < 4
)

UNION ALL

SELECT 'Nome de cliente com pronome de tratamento', 'silver.clientes', 'CORRIGIDO', COUNT(*), CAST(NULL AS DECIMAL(20,2))
FROM silver.clientes
WHERE nome_original RLIKE '^(Sr|Sra|Srta|Dr|Dra)[.] ';
