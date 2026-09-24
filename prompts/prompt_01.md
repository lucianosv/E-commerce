# Prompt 1: a silver

Vamos construir a camada silver de um e-commerce brasileiro no Databricks, como um Lakeflow
Declarative Pipeline dentro deste bundle. Use sempre o perfil de CLI "imersao".

CONTEXTO
- Todo o trabalho acontece no catálogo projetoaovivo. Nunca use outro catálogo.
- A bronze já existe e é sobrescrita por outra ingestão: projetoaovivo.bronze.vendas,
  bronze.produtos, bronze.clientes e bronze.preco_competidores.
- Antes de escrever código, explore a bronze (colunas, tipos, contagens) e procure problemas de
  qualidade: nulos, duplicatas, vendas de produtos não cadastrados, vendas antes da criação do
  produto, preços de concorrente fora do padrão, nomes de clientes com pronome de tratamento.
  Me mostre os números antes de escrever qualquer código.

CONVENÇÕES (grave no CLAUDE.md)
- Catálogo projetoaovivo, schemas bronze, silver e gold.
- Nomes de tabelas e colunas em português, snake_case, sem acento.
- Silver em Python (from pyspark import pipelines as dp), gold em SQL.
- Um arquivo por tabela: transformations/silver/<tabela>.py e transformations/gold/<tabela>.sql.
  Apague os exemplos que vieram no template.
- Todas as tabelas são materialized views com leitura batch (spark.read.table), nunca streaming
  table, porque a bronze é sobrescrita a cada execução.
- Pipeline serverless, catálogo projetoaovivo, schema padrão silver. Golds publicadas como
  gold.<tabela>. Nomes no código sempre schema.tabela, sem catálogo.
- Cada arquivo começa com comentários explicando o PORQUÊ das regras, em português.
- Dinheiro sempre DECIMAL(10,2).
- Problema de qualidade conhecido é MARCADO em uma coluna e medido com @dp.expect (warn).
  Nunca descarte linhas: apagar vendas mudaria a receita.
- @dp.expect_all_or_fail só para o que nunca pode acontecer.
- Sempre rode databricks bundle validate --strict antes do deploy.

TABELAS SILVER
1. silver.produtos (chave id_produto): remove duplicatas por id_produto; trim em nome_produto;
   preco_atual em DECIMAL(10,2); faixa_preco = PREMIUM (> 1000), MEDIO (> 500) ou BASICO.
   Fail: id_produto preenchido, preco_atual > 0.
2. silver.clientes (chave id_cliente): remove duplicatas; guarda o nome original em nome_original;
   nome_cliente sem pronome de tratamento no início (Sr., Sra., Srta., Dr., Dra.) e em formato
   título; estado (UF) em maiúsculas; nome_estado e regiao (Norte, Nordeste, Centro-Oeste, Sudeste,
   Sul) a partir de um mapeamento fixo das 27 UFs do IBGE, declarado no próprio arquivo (não existe
   tabela de estados na bronze).
   Fail: id_cliente preenchido, regiao preenchida.
3. silver.preco_competidores (chave id_produto + nome_concorrente): remove duplicatas;
   preco_concorrente em DECIMAL(10,2); data_coleta de texto para timestamp;
   preco_suspeito = true quando o preço do concorrente é menor que 60% do nosso preco_atual.
   Fail: id_produto preenchido, preço > 0. Warn: preco_plausivel = NOT preco_suspeito.
4. silver.vendas (chave id_venda): remove duplicatas; preco_unitario em DECIMAL(10,2);
   receita = quantidade × preco_unitario em DECIMAL(10,2); data (date), hora (0-23),
   dia_semana_num (1 = domingo ... 7 = sábado) e dia_semana em português (Domingo, Segunda,
   Terça, Quarta, Quinta, Sexta, Sábado); produto_cadastrado = false quando o id_produto não existe
   em silver.produtos; venda_antes_do_cadastro = true quando data_venda é anterior à data_criacao
   do produto.
   Fail: id_venda, data_venda, id_cliente, id_produto, quantidade e preco_unitario preenchidos;
   quantidade > 0; preco_unitario > 0; canal_venda em ('ecommerce', 'loja_fisica').
   Warn: produto_cadastrado; venda_depois_do_cadastro = NOT venda_antes_do_cadastro.

TESTES E JOB
- Crie o notebook testes/testes_qualidade.py (formato source do Databricks, widget catalogo com
  padrão projetoaovivo). Cada teste é uma consulta que conta linhas com problema; se alguma achar,
  o notebook falha com AssertionError e mostra uma tabela com o resultado de cada teste.
  Por enquanto: chaves únicas das 4 silver; receita = quantidade × preco_unitario; vendas de produto
  não cadastrado abaixo de 1% do total.
- Crie o Job "Pipeline E-commerce" no bundle: roda o pipeline e depois o notebook de testes.

NO FIM
Valide, faça o deploy em dev, rode o Job e acompanhe até terminar (se falhar, leia o erro e corrija).
Me mostre as métricas das expectations no event log do pipeline.
Números esperados: 3.020 vendas, receita total R$ 974.077,28, 20 vendas de produto não cadastrado
(R$ 4.240,01), 5 vendas antes do cadastro (R$ 325,88), 55 preços de concorrente suspeitos,
11 clientes com pronome de tratamento. Clientes por região: Norte 17, Nordeste 12, Centro-Oeste 9,
Sudeste 8, Sul 4.
