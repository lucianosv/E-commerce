# Prompt 3: gold da Diretoria Comercial

Agora a gold da Diretoria Comercial, no catálogo projetoaovivo. A diretora quer saber: quanto
vendemos, quando (dia, hora, dia da semana), em qual canal e com quais produtos. Siga as regras de
gold do CLAUDE.md: SQL, CREATE OR REFRESH MATERIALIZED VIEW, tipo e COMMENT em todas as colunas,
COMMENT na tabela, em português. Cite o período dos dados (13/12/2025 a 11/01/2026) no comentário
das tabelas.

TABELAS
1. gold.vendas_temporais, uma linha por data × hora × canal_venda.
   Colunas: data, dia_semana, dia_semana_num, hora, canal_venda, total_vendas (COUNT), itens_vendidos
   (SUM quantidade), receita (SUM), clientes_unicos (COUNT DISTINCT id_cliente).
   Aviso no comentário de clientes_unicos: não somar entre linhas; para clientes únicos no período,
   usar gold.clientes_segmentacao.
2. gold.vendas_produtos, uma linha por produto vendido (LEFT JOIN de silver.vendas com silver.produtos).
   Colunas: id_produto; nome_produto, categoria e marca (quando o produto não existe: "Produto não
   cadastrado" e "Não cadastrado"); faixa_preco; produto_cadastrado; total_vendas; itens_vendidos;
   receita; ticket_medio (ROUND(AVG(receita), 2)); ranking_receita (ROW_NUMBER geral por receita desc);
   ranking_na_categoria (ROW_NUMBER por categoria).
   Aviso no comentário de nome_produto: produtos diferentes têm o mesmo nome, contar por id_produto.
3. gold.vendas_detalhadas, uma linha por venda, para perguntas que cruzam diretorias ("receita por
   região e categoria", "canal preferido dos VIPs") e para os filtros cruzados do dashboard.
   Colunas: id_venda, data_venda, data, dia_semana, dia_semana_num, hora, canal_venda, id_produto,
   nome_produto, categoria, marca, faixa_preco (mesmos "não cadastrado" da anterior), id_cliente,
   nome_cliente, estado, regiao e segmento_cliente (de gold.clientes_segmentacao), quantidade,
   preco_unitario, receita, produto_cadastrado, venda_antes_do_cadastro. CLUSTER BY (data).

TESTES
- receita total de vendas_temporais, vendas_produtos e vendas_detalhadas igual à de silver.vendas;
- vendas_detalhadas com o mesmo número de linhas de silver.vendas e id_venda único;
- toda venda de vendas_detalhadas com segmento e região.

NO FIM
Valide, faça o deploy em dev, rode o Job e confira: receita R$ 974.077,28 e 3.020 vendas em
silver.vendas, vendas_temporais, vendas_produtos e vendas_detalhadas; 2.155 vendas no ecommerce.
