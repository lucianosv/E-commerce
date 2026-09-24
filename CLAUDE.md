# CLAUDE.md — Imersão Jornada Databricks (Aula 3)

## Catálogo e Schemas

- Catálogo: **ecommerce**. Nunca use outro catálogo.
- Schemas: **bronze**, **silver** e **gold**.
- Nomes de tabelas e colunas em português, snake_case, sem acento.

## Convenções

- Silver em Python (`from pyspark import pipelines as dp`), gold em SQL.
- Um arquivo por tabela: `pipeline/silver/<tabela>.py` e `pipeline/gold/<tabela>.sql`.
- Todas as tabelas gold são `CREATE OR REFRESH MATERIALIZED VIEW` (no pipeline) ou `CREATE OR REPLACE TABLE` (no notebook 02_gold).
- Todas as tabelas são materialized views com leitura batch (`spark.read.table`), nunca streaming table.
- Pipeline serverless, catálogo ecommerce, schema padrão silver. Golds publicadas como `gold.<tabela>`.
- Nomes no código sempre `schema.tabela`, sem catálogo.
- Cada arquivo começa com comentários explicando o PORQUÊ das regras, em português.
- Dinheiro sempre `DECIMAL(10,2)` (ou `DECIMAL(20,2)` em somatórios gold).
- Problema de qualidade conhecido é MARCADO em uma coluna e medido com `@dp.expect` (warn).
- Nunca descarte linhas: apagar vendas mudaria a receita.
- `@dp.expect_all_or_fail` só para o que nunca pode acontecer.
- Toda coluna do schema gold tem `COMMENT` em português (o Genie lê para gerar SQL).
- Toda tabela gold tem `COMMENT` citando o período dos dados.
- Sempre rode `databricks bundle validate --strict` antes do deploy.

## Tabelas

### Bronze (externa, sobrescrita a cada execução)

- `bronze.vendas`, `bronze.produtos`, `bronze.clientes`, `bronze.preco_competidores`, `bronze.estados_ibge`

### Silver (pipeline Python, materialized views)

- `silver.produtos` — chave `id_produto`; faixa_preco (PREMIUM > 1000, MEDIO > 500, BASICO).
- `silver.clientes` — chave `id_cliente`; nome sem pronome; região via API IBGE.
- `silver.preco_competidores` — chave `id_produto` + `nome_concorrente`; `preco_suspeito` < 60% do nosso preço.
- `silver.vendas` — chave `id_venda`; receita = quantidade × preco_unitario; marca produto_cadastrado e venda_antes_do_cadastro.

### Gold (pipeline SQL, materialized views)

- `gold.vendas_temporais` — grão: data × hora × canal. Diretoria Comercial.
- `gold.vendas_produtos` — grão: produto. Rankings geral e por categoria. Diretoria Comercial.
- `gold.vendas_detalhadas` — grão: venda. JOIN com produtos e clientes_segmentacao. CLUSTER BY (data). Cruzamento entre diretorias.
- `gold.clientes_segmentacao` — grão: cliente. Segmentos VIP/TOP_TIER/REGULAR. Diretoria de Customer Success.
- `gold.precos_competitividade` — grão: produto com preço de concorrente. Classificação vs 4 concorrentes. Diretoria de Pricing.

## Números de referência (período 13/12/2025 a 11/01/2026)

### Silver

- **3.020 vendas**, receita total **R$ 974.077,28**.
- Canal: **2.155 ecommerce**, 865 loja_fisica.
- **20 vendas** de produto não cadastrado (R$ 4.240,01).
- **5 vendas** antes do cadastro do produto (R$ 325,88).
- **55 preços** de concorrente suspeitos.
- **11 clientes** com pronome de tratamento.
- Clientes por região: Norte 17, Nordeste 12, Centro-Oeste 9, Sudeste 8, Sul 4.

### Gold · clientes_segmentacao

- **50 clientes**: 10 VIP, 25 TOP_TIER, 15 REGULAR.
- Limites: VIP a partir de R$ 22.000; TOP_TIER de R$ 17.000 a R$ 21.999,99; REGULAR abaixo de R$ 17.000.
- Maior cliente: Ana Sophia Pereira (MG, R$ 30.716,63).

### Gold · precos_competitividade

- **215 produtos** monitorados.
- Classificação: 35 MAIS_CARO_QUE_TODOS, 92 ACIMA_DA_MEDIA, 6 NA_MEDIA, 76 ABAIXO_DA_MEDIA, 6 MAIS_BARATO_QUE_TODOS.
- **15 produtos** com preço suspeito (possível promoção relâmpago ou erro de coleta).
- Concorrentes: Mercado Livre, Amazon, Magalu e Shopee.

### Reconciliação

- A receita R$ 974.077,28 bate em silver.vendas, vendas_temporais, vendas_produtos, vendas_detalhadas e clientes_segmentacao.
- O total de 3.020 vendas bate em silver.vendas, vendas_temporais, vendas_produtos e vendas_detalhadas.

## Testes

- Notebook `testes/04_testes_qualidade` com widget `catalogo` (padrão `ecommerce`).
- Cada teste é uma consulta que conta linhas com problema; se alguma achar, o notebook falha com `AssertionError`.
- Testes: unicidade de chaves, campos obrigatórios, domínio, regras de negócio, reconciliação de receita, comentários em todas as colunas do schema gold.

## Job

- Job "Pipeline E-commerce" no bundle: roda o pipeline e depois o notebook de testes.
