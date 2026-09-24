# Prompt 4: gold da Diretoria de Pricing

Por fim, a gold da Diretoria de Pricing, no catálogo projetoaovivo. O diretor quer saber se estamos
mais caros que a concorrência (Mercado Livre, Amazon, Magalu e Shopee) e em quais produtos agir.
Siga as regras de gold do CLAUDE.md: SQL, CREATE OR REFRESH MATERIALIZED VIEW, tipo e COMMENT em
todas as colunas, COMMENT na tabela, em português.

TABELA
gold.precos_competitividade, uma linha por produto que tem preço de concorrente (JOIN de silver.produtos
com a agregação de silver.preco_competidores; LEFT JOIN com a receita de silver.vendas).
Colunas: id_produto, nome_produto, categoria, marca, nosso_preco (preco_atual),
preco_medio_concorrentes (ROUND(AVG, 2)), preco_minimo_concorrentes, preco_maximo_concorrentes,
total_concorrentes, diferenca_pct_vs_media e diferenca_pct_vs_minimo (em pontos percentuais,
ROUND(..., 2): 10 = 10% mais caro), classificacao_preco, possui_preco_suspeito (algum concorrente
com preco_suspeito), receita e itens_vendidos (0 se nunca vendeu).

CLASSIFICAÇÃO (nesta ordem)
- MAIS_CARO_QUE_TODOS: nosso preço acima do maior preço dos concorrentes
- MAIS_BARATO_QUE_TODOS: abaixo do menor
- ACIMA_DA_MEDIA, ABAIXO_DA_MEDIA ou NA_MEDIA, comparando com a média

O produto com preço suspeito continua em todas as contas: promoção relâmpago existe. A coluna
possui_preco_suspeito só alerta que o preço precisa ser confirmado antes de reagir. Explique isso no
comentário do arquivo e da coluna.

TESTES
- id_produto único na tabela.

NO FIM
Valide, faça o deploy em dev, rode o Job até ficar verde e confira: 215 produtos, 35 mais caros que
todos os concorrentes, 15 com preço suspeito. Depois me dê um resumo de tudo o que foi criado nos
quatro prompts e atualize o CLAUDE.md com os números de referência.
