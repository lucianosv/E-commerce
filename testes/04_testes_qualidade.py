# Databricks notebook source
# MAGIC %md
# MAGIC # Aula 3 · Testes de qualidade de dados
# MAGIC
# MAGIC Um pipeline profissional não termina quando a tabela é criada. Termina quando alguém **prova** que ela está certa.
# MAGIC
# MAGIC Cada teste abaixo é uma consulta que conta **linhas com problema**. Zero é o resultado esperado. Se qualquer teste encontrar problema, o notebook falha, o Job fica vermelho e o dashboard não mostra número errado para o diretor sem que ninguém saiba.
# MAGIC
# MAGIC | Tipo | O que verifica |
# MAGIC |---|---|
# MAGIC | Unicidade | Não existe ID repetido |
# MAGIC | Não nulo | Colunas obrigatórias preenchidas |
# MAGIC | Domínio | Valores dentro da lista permitida |
# MAGIC | Regra de negócio | Quantidade e preço positivos, segmentação coerente |
# MAGIC | Reconciliação | A receita bate entre silver e todas as tabelas gold |
# MAGIC | Limite tolerado | Vendas de produtos não cadastrados abaixo de 1% |

# COMMAND ----------

dbutils.widgets.text("catalogo", "ecommerce")
catalogo = dbutils.widgets.get("catalogo")
spark.sql(f"USE CATALOG {catalogo}")

# COMMAND ----------

TESTES = {
    # Unicidade
    "silver.vendas: id_venda único":
        "SELECT id_venda FROM silver.vendas GROUP BY id_venda HAVING COUNT(*) > 1",
    "silver.produtos: id_produto único":
        "SELECT id_produto FROM silver.produtos GROUP BY id_produto HAVING COUNT(*) > 1",
    "silver.clientes: id_cliente único":
        "SELECT id_cliente FROM silver.clientes GROUP BY id_cliente HAVING COUNT(*) > 1",
    "gold.precos_competitividade: um produto por linha":
        "SELECT id_produto FROM gold.precos_competitividade GROUP BY id_produto HAVING COUNT(*) > 1",
    "gold.clientes_segmentacao: id_cliente único":
        "SELECT id_cliente FROM gold.clientes_segmentacao GROUP BY id_cliente HAVING COUNT(*) > 1",
    "gold.vendas_detalhadas: id_venda único":
        "SELECT id_venda FROM gold.vendas_detalhadas GROUP BY id_venda HAVING COUNT(*) > 1",

    # Não nulo
    "silver.vendas: campos obrigatórios preenchidos":
        "SELECT * FROM silver.vendas WHERE id_venda IS NULL OR data_venda IS NULL OR id_cliente IS NULL "
        "OR id_produto IS NULL OR quantidade IS NULL OR preco_unitario IS NULL",
    "silver.clientes: todo cliente tem região (API do IBGE)":
        "SELECT * FROM silver.clientes WHERE regiao IS NULL",

    # Domínio
    "silver.vendas: canal é ecommerce ou loja_fisica":
        "SELECT * FROM silver.vendas WHERE canal_venda NOT IN ('ecommerce', 'loja_fisica')",
    "gold.clientes_segmentacao: segmento válido":
        "SELECT * FROM gold.clientes_segmentacao WHERE segmento_cliente NOT IN ('VIP', 'TOP_TIER', 'REGULAR')",

    # Regra de negócio
    "silver.vendas: quantidade e preço positivos":
        "SELECT * FROM silver.vendas WHERE quantidade <= 0 OR preco_unitario <= 0",
    "silver.vendas: receita = quantidade × preço":
        "SELECT * FROM silver.vendas WHERE receita <> quantidade * preco_unitario",
    "gold.clientes_segmentacao: VIP tem receita a partir de R$ 22 mil":
        "SELECT * FROM gold.clientes_segmentacao WHERE segmento_cliente = 'VIP' AND receita < 22000",

    # Reconciliação
    "gold.vendas_temporais: receita bate com a silver":
        "SELECT 1 FROM (SELECT SUM(receita) AS r FROM silver.vendas) s, "
        "(SELECT SUM(receita) AS r FROM gold.vendas_temporais) g WHERE s.r <> g.r",
    "gold.vendas_produtos: receita bate com a silver":
        "SELECT 1 FROM (SELECT SUM(receita) AS r FROM silver.vendas) s, "
        "(SELECT SUM(receita) AS r FROM gold.vendas_produtos) g WHERE s.r <> g.r",
    "gold.clientes_segmentacao: receita bate com a silver":
        "SELECT 1 FROM (SELECT SUM(receita) AS r FROM silver.vendas) s, "
        "(SELECT SUM(receita) AS r FROM gold.clientes_segmentacao) g WHERE s.r <> g.r",
    "gold.vendas_detalhadas: receita bate com a silver":
        "SELECT 1 FROM (SELECT SUM(receita) AS r FROM silver.vendas) s, "
        "(SELECT SUM(receita) AS r FROM gold.vendas_detalhadas) g WHERE s.r <> g.r",

    # Completude
    "gold.vendas_detalhadas: mesmo número de linhas que silver.vendas":
        "SELECT 1 FROM (SELECT COUNT(*) AS c FROM silver.vendas) s, "
        "(SELECT COUNT(*) AS c FROM gold.vendas_detalhadas) g WHERE s.c <> g.c",
    "gold.vendas_detalhadas: toda venda tem segmento e região":
        "SELECT * FROM gold.vendas_detalhadas WHERE segmento_cliente IS NULL OR regiao IS NULL",

    # Limite tolerado: o problema existe e é conhecido; o teste alerta se ele crescer
    "silver.vendas: produtos não cadastrados abaixo de 1% das vendas":
        "SELECT 1 FROM silver.vendas HAVING AVG(CASE WHEN produto_cadastrado THEN 0 ELSE 1 END) >= 0.01",

    # Comentários: toda coluna do schema gold com comentário (Genie precisa para gerar SQL correto)
    "gold: toda coluna tem comentário":
        "SELECT table_name, column_name FROM information_schema.columns "
        "WHERE table_schema = 'gold' "
        "AND NOT table_name LIKE '\\\\_\\\\_materialization%' "
        "AND comment IS NULL",
}

# COMMAND ----------

resultados = []
for nome, consulta in TESTES.items():
    problemas = spark.sql(consulta).count()
    resultados.append((nome, problemas, "✅ OK" if problemas == 0 else "❌ FALHOU"))

display(spark.createDataFrame(resultados, "teste string, linhas_com_problema long, status string"))

# COMMAND ----------

falhas = [f"{nome} ({n} linhas)" for nome, n, _ in resultados if n > 0]
if falhas:
    raise AssertionError("Testes de qualidade falharam:\n- " + "\n- ".join(falhas))

print(f"Todos os {len(resultados)} testes passaram.")