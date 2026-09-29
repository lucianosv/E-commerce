-- Databricks notebook source
-- Aula 4 · Preparar o dado para a IA
-- "Todo mundo quer IA. Ninguém tem o dado organizado."
--
-- O Genie lê o nome e o comentário de cada tabela e coluna para decidir qual SQL escrever.
-- Este notebook documenta as 4 tabelas gold para o Genie.

USE CATALOG IDENTIFIER(:catalogo);

-- -----------------------------------------------------------------------------
-- Antes: o que o Genie enxerga hoje (veja a coluna comment: vazia)
-- -----------------------------------------------------------------------------
DESCRIBE TABLE gold.clientes_segmentacao;

-- -----------------------------------------------------------------------------
-- Vendas: gold.vendas_temporais
-- -----------------------------------------------------------------------------
COMMENT ON TABLE gold.vendas_temporais IS
  'Vendas agregadas por dia, hora e canal. Use para perguntas de receita, número de vendas e ticket médio ao longo do tempo, por dia da semana, por hora ou por canal. Inclui todas as vendas, mesmo de produtos não cadastrados. Período dos dados: 13/12/2025 a 11/01/2026.';

COMMENT ON COLUMN gold.vendas_temporais.data IS 'Data da venda (sem horário).';
COMMENT ON COLUMN gold.vendas_temporais.dia_semana IS 'Dia da semana em português: Domingo, Segunda, Terça, Quarta, Quinta, Sexta, Sábado.';
COMMENT ON COLUMN gold.vendas_temporais.dia_semana_num IS 'Número do dia da semana para ordenação: 1 = Domingo ... 7 = Sábado.';
COMMENT ON COLUMN gold.vendas_temporais.hora IS 'Hora do dia da venda, de 0 a 23.';
COMMENT ON COLUMN gold.vendas_temporais.canal_venda IS 'Canal da venda: ecommerce (site) ou loja_fisica.';
COMMENT ON COLUMN gold.vendas_temporais.total_vendas IS 'Quantidade de vendas (pedidos). Somar para totalizar.';
COMMENT ON COLUMN gold.vendas_temporais.itens_vendidos IS 'Quantidade de unidades vendidas. Somar para totalizar.';
COMMENT ON COLUMN gold.vendas_temporais.receita IS 'Receita bruta em reais (R$) = quantidade × preço unitário. Somar para totalizar.';
COMMENT ON COLUMN gold.vendas_temporais.clientes_unicos IS 'Clientes distintos NAQUELA linha (dia, hora, canal). Não somar entre linhas: para clientes únicos no período use gold.clientes_segmentacao.';

-- -----------------------------------------------------------------------------
-- Vendas: gold.vendas_produtos
-- -----------------------------------------------------------------------------
COMMENT ON TABLE gold.vendas_produtos IS
  'Desempenho de vendas por produto no período: receita, itens vendidos, ticket médio e rankings. Use para "produtos mais vendidos", "receita por categoria" e "receita por marca". Vendas de produtos fora do catálogo aparecem com nome "Produto não cadastrado".';

COMMENT ON COLUMN gold.vendas_produtos.id_produto IS 'Identificador do produto (prefixo prd_).';
COMMENT ON COLUMN gold.vendas_produtos.nome_produto IS 'Nome do produto. Atenção: produtos diferentes podem ter o mesmo nome; use id_produto para contar produtos.';
COMMENT ON COLUMN gold.vendas_produtos.categoria IS 'Categoria do produto, por exemplo Eletrônicos, Casa, Cozinha, Tênis, Áudio, Games.';
COMMENT ON COLUMN gold.vendas_produtos.marca IS 'Marca do produto.';
COMMENT ON COLUMN gold.vendas_produtos.faixa_preco IS 'Faixa de preço do produto: PREMIUM (acima de R$ 1.000), MEDIO (R$ 500,01 a R$ 1.000) ou BASICO (até R$ 500).';
COMMENT ON COLUMN gold.vendas_produtos.produto_cadastrado IS 'false quando a venda é de um produto que não existe no catálogo (problema de qualidade de dados).';
COMMENT ON COLUMN gold.vendas_produtos.total_vendas IS 'Quantidade de vendas (pedidos) do produto.';
COMMENT ON COLUMN gold.vendas_produtos.itens_vendidos IS 'Unidades vendidas do produto.';
COMMENT ON COLUMN gold.vendas_produtos.receita IS 'Receita bruta do produto em reais (R$).';
COMMENT ON COLUMN gold.vendas_produtos.ticket_medio IS 'Receita média por venda do produto, em reais (R$).';
COMMENT ON COLUMN gold.vendas_produtos.ranking_receita IS 'Posição do produto no ranking geral de receita (1 = maior receita).';
COMMENT ON COLUMN gold.vendas_produtos.ranking_na_categoria IS 'Posição do produto no ranking de receita dentro da própria categoria (1 = maior).';

-- -----------------------------------------------------------------------------
-- Clientes: gold.clientes_segmentacao
-- -----------------------------------------------------------------------------
COMMENT ON TABLE gold.clientes_segmentacao IS
  'Uma linha por cliente com receita, compras, ticket médio, região e segmento. Use para perguntas sobre melhores clientes, clientes VIP, segmentos, estados e regiões.';

COMMENT ON COLUMN gold.clientes_segmentacao.id_cliente IS 'Identificador do cliente (prefixo cus_).';
COMMENT ON COLUMN gold.clientes_segmentacao.nome_cliente IS 'Nome do cliente.';
COMMENT ON COLUMN gold.clientes_segmentacao.estado IS 'Sigla da UF do cliente, por exemplo SP, RJ, MG.';
COMMENT ON COLUMN gold.clientes_segmentacao.nome_estado IS 'Nome completo do estado (fonte: API do IBGE).';
COMMENT ON COLUMN gold.clientes_segmentacao.regiao IS 'Região do Brasil: Norte, Nordeste, Centro-Oeste, Sudeste ou Sul (fonte: API do IBGE).';
COMMENT ON COLUMN gold.clientes_segmentacao.total_compras IS 'Quantidade de compras do cliente no período.';
COMMENT ON COLUMN gold.clientes_segmentacao.receita IS 'Receita total gerada pelo cliente no período, em reais (R$).';
COMMENT ON COLUMN gold.clientes_segmentacao.ticket_medio IS 'Valor médio por compra do cliente, em reais (R$).';
COMMENT ON COLUMN gold.clientes_segmentacao.primeira_compra IS 'Data da primeira compra do cliente.';
COMMENT ON COLUMN gold.clientes_segmentacao.ultima_compra IS 'Data da compra mais recente do cliente.';
COMMENT ON COLUMN gold.clientes_segmentacao.segmento_cliente IS 'Segmento pela receita no período: VIP (a partir de R$ 22.000), TOP_TIER (R$ 17.000 a R$ 21.999,99) ou REGULAR (abaixo de R$ 17.000).';
COMMENT ON COLUMN gold.clientes_segmentacao.ranking_receita IS 'Posição do cliente no ranking de receita (1 = cliente que mais gerou receita).';

-- -----------------------------------------------------------------------------
-- Pricing: gold.precos_competitividade
-- -----------------------------------------------------------------------------
COMMENT ON TABLE gold.precos_competitividade IS
  'Nosso preço comparado ao de 4 concorrentes (Mercado Livre, Amazon, Magalu e Shopee), uma linha por produto monitorado. Use para perguntas de competitividade, produtos caros ou baratos em relação ao mercado.';

COMMENT ON COLUMN gold.precos_competitividade.id_produto IS 'Identificador do produto (prefixo prd_).';
COMMENT ON COLUMN gold.precos_competitividade.nome_produto IS 'Nome do produto.';
COMMENT ON COLUMN gold.precos_competitividade.categoria IS 'Categoria do produto.';
COMMENT ON COLUMN gold.precos_competitividade.marca IS 'Marca do produto.';
COMMENT ON COLUMN gold.precos_competitividade.nosso_preco IS 'Nosso preço atual de venda, em reais (R$).';
COMMENT ON COLUMN gold.precos_competitividade.preco_medio_concorrentes IS 'Média dos preços dos concorrentes para o produto, em reais (R$).';
COMMENT ON COLUMN gold.precos_competitividade.preco_minimo_concorrentes IS 'Menor preço entre os concorrentes, em reais (R$).';
COMMENT ON COLUMN gold.precos_competitividade.preco_maximo_concorrentes IS 'Maior preço entre os concorrentes, em reais (R$).';
COMMENT ON COLUMN gold.precos_competitividade.total_concorrentes IS 'Quantos concorrentes têm preço coletado para o produto (1 a 4).';
COMMENT ON COLUMN gold.precos_competitividade.diferenca_pct_vs_media IS 'Diferença percentual do nosso preço contra a média dos concorrentes, em pontos percentuais (10 = 10% mais caro; -5 = 5% mais barato).';
COMMENT ON COLUMN gold.precos_competitividade.diferenca_pct_vs_minimo IS 'Diferença percentual do nosso preço contra o concorrente mais barato, em pontos percentuais.';
COMMENT ON COLUMN gold.precos_competitividade.classificacao_preco IS 'Posição de preço: MAIS_CARO_QUE_TODOS, ACIMA_DA_MEDIA, NA_MEDIA, ABAIXO_DA_MEDIA ou MAIS_BARATO_QUE_TODOS.';
COMMENT ON COLUMN gold.precos_competitividade.receita IS 'Receita do produto no período, em reais (R$). Zero se nunca vendeu.';
COMMENT ON COLUMN gold.precos_competitividade.itens_vendidos IS 'Unidades vendidas do produto no período.';

-- -----------------------------------------------------------------------------
-- Vendas detalhadas: gold.vendas_detalhadas
-- -----------------------------------------------------------------------------
COMMENT ON TABLE gold.vendas_detalhadas IS
  'Venda por venda: cada linha é um pedido com calendário, canal, produto, categoria, marca, cliente, UF, região, segmento, receita e marcações de qualidade. Use para filtros cruzados no dashboard e perguntas do Genie que cruzam diretorias.';

COMMENT ON COLUMN gold.vendas_detalhadas.id_venda IS 'Identificador único da venda.';
COMMENT ON COLUMN gold.vendas_detalhadas.data_venda IS 'Data e hora da venda.';
COMMENT ON COLUMN gold.vendas_detalhadas.data IS 'Data da venda (sem horário).';
COMMENT ON COLUMN gold.vendas_detalhadas.dia_semana IS 'Dia da semana em português: Domingo, Segunda, Terça, Quarta, Quinta, Sexta, Sábado.';
COMMENT ON COLUMN gold.vendas_detalhadas.dia_semana_num IS 'Número do dia da semana para ordenação: 1 = Domingo ... 7 = Sábado.';
COMMENT ON COLUMN gold.vendas_detalhadas.hora IS 'Hora do dia da venda, de 0 a 23.';
COMMENT ON COLUMN gold.vendas_detalhadas.canal_venda IS 'Canal da venda: ecommerce (site) ou loja_fisica.';
COMMENT ON COLUMN gold.vendas_detalhadas.id_produto IS 'Identificador do produto (prefixo prd_).';
COMMENT ON COLUMN gold.vendas_detalhadas.nome_produto IS 'Nome do produto.';
COMMENT ON COLUMN gold.vendas_detalhadas.categoria IS 'Categoria do produto.';
COMMENT ON COLUMN gold.vendas_detalhadas.marca IS 'Marca do produto.';
COMMENT ON COLUMN gold.vendas_detalhadas.faixa_preco IS 'Faixa de preço: PREMIUM (acima de R$ 1.000), MEDIO (R$ 500,01 a R$ 1.000) ou BASICO (até R$ 500).';
COMMENT ON COLUMN gold.vendas_detalhadas.produto_cadastrado IS 'false quando a venda é de um produto que não existe no catálogo.';
COMMENT ON COLUMN gold.vendas_detalhadas.venda_antes_do_cadastro IS 'true quando a venda é anterior à criação do produto no catálogo.';
COMMENT ON COLUMN gold.vendas_detalhadas.id_cliente IS 'Identificador do cliente (prefixo cus_).';
COMMENT ON COLUMN gold.vendas_detalhadas.nome_cliente IS 'Nome do cliente.';
COMMENT ON COLUMN gold.vendas_detalhadas.estado IS 'Sigla da UF do cliente.';
COMMENT ON COLUMN gold.vendas_detalhadas.regiao IS 'Região do Brasil: Norte, Nordeste, Centro-Oeste, Sudeste ou Sul.';
COMMENT ON COLUMN gold.vendas_detalhadas.segmento_cliente IS 'Segmento pela receita: VIP (a partir de R$ 22.000), TOP_TIER (R$ 17.000 a R$ 21.999,99) ou REGULAR (abaixo de R$ 17.000).';
COMMENT ON COLUMN gold.vendas_detalhadas.quantidade IS 'Quantidade de unidades vendidas nesta venda.';
COMMENT ON COLUMN gold.vendas_detalhadas.preco_unitario IS 'Preço unitário do produto na venda, em reais (R$).';
COMMENT ON COLUMN gold.vendas_detalhadas.receita IS 'Receita da venda = quantidade × preço unitário, em reais (R$).';

-- -----------------------------------------------------------------------------
-- Qualidade dos dados: gold.qualidade_dados
-- -----------------------------------------------------------------------------
COMMENT ON TABLE gold.qualidade_dados IS
  'Placar de qualidade dos dados: uma linha por regra, com quantas linhas e quanta receita cada problema afeta. Use para perguntas sobre confiabilidade dos números, vendas de produtos não cadastrados e preços suspeitos de concorrentes.';

COMMENT ON COLUMN gold.qualidade_dados.regra IS 'Descrição da regra de qualidade verificada.';
COMMENT ON COLUMN gold.qualidade_dados.tabela IS 'Tabela silver onde a regra é verificada.';
COMMENT ON COLUMN gold.qualidade_dados.severidade IS 'ALERTA (resolver na origem), INFORMATIVO (muda a leitura dos números) ou CORRIGIDO (a silver já trata).';
COMMENT ON COLUMN gold.qualidade_dados.linhas_afetadas IS 'Quantidade de linhas da tabela que caem na regra.';
COMMENT ON COLUMN gold.qualidade_dados.receita_afetada IS 'Receita em reais (R$) das vendas afetadas. Vazia quando a regra não envolve vendas.';

-- -----------------------------------------------------------------------------
-- Depois: o mesmo DESCRIBE, agora com contexto
-- -----------------------------------------------------------------------------
DESCRIBE TABLE gold.clientes_segmentacao;