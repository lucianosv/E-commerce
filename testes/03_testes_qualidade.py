# Databricks notebook source
# MAGIC %md
# MAGIC # Aula 3 · Testes de qualidade de dados
# MAGIC
# MAGIC Um pipeline profissional não termina quando a tabela é criada. Termina quando alguém **prova** que ela está certa.
# MAGIC
# MAGIC A qualidade fica em duas camadas, cada uma no lugar certo:
# MAGIC
# MAGIC | Onde | O que verifica | Por quê |
# MAGIC |---|---|---|
# MAGIC | **Expectations** no pipeline (`pipeline/silver/*.py`) | Regras **linha a linha**: campo obrigatório, quantidade positiva, canal conhecido, produto cadastrado | Olham cada linha no momento em que ela é gravada e param o pipeline antes de a gold ser calculada |
# MAGIC | **Este notebook**, depois do pipeline | Regras **entre linhas e entre tabelas**: chave única, receita que bate, limite tolerado, documentação | Uma expectation não enxerga as outras linhas nem as outras tabelas |
# MAGIC
# MAGIC Cada teste abaixo é uma consulta que conta **linhas com problema**. Zero é o resultado esperado. Se qualquer teste encontrar problema, o notebook falha, o Job fica vermelho e o dashboard não mostra número errado para o diretor sem que ninguém saiba.

# COMMAND ----------

dbutils.widgets.text("catalogo", "ecommerce")
catalogo = dbutils.widgets.get("catalogo")
spark.sql(f"USE CATALOG {catalogo}")

# COMMAND ----------

def receita_bate(tabela: str) -> str:
    """Reconciliação: a receita total da tabela gold é igual à da silver."""
    return (
        "SELECT 1 FROM (SELECT SUM(receita) AS r FROM silver.vendas) s, "
        f"(SELECT SUM(receita) AS r FROM {tabela}) g WHERE s.r <> g.r"
    )


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
    "gold.vendas_detalhadas: uma venda por linha":
        "SELECT id_venda FROM gold.vendas_detalhadas GROUP BY id_venda HAVING COUNT(*) > 1",
    "gold.qualidade_dados: uma linha por regra":
        "SELECT regra FROM gold.qualidade_dados GROUP BY regra HAVING COUNT(*) > 1",

    # Domínio
    "gold.clientes_segmentacao: segmento válido":
        "SELECT * FROM gold.clientes_segmentacao WHERE segmento_cliente NOT IN ('VIP', 'TOP_TIER', 'REGULAR')",
    "gold.qualidade_dados: severidade válida":
        "SELECT * FROM gold.qualidade_dados WHERE severidade NOT IN ('ALERTA', 'INFORMATIVO', 'CORRIGIDO')",

    # Regra de negócio
    "silver.vendas: receita = quantidade × preço":
        "SELECT * FROM silver.vendas WHERE receita <> quantidade * preco_unitario",
    "gold.clientes_segmentacao: VIP tem receita a partir de R$ 22 mil":
        "SELECT * FROM gold.clientes_segmentacao WHERE segmento_cliente = 'VIP' AND receita < 22000",
    "gold.vendas_detalhadas: toda venda tem segmento e região":
        "SELECT * FROM gold.vendas_detalhadas WHERE segmento_cliente IS NULL OR regiao IS NULL",

    # Reconciliação
    "gold.vendas_temporais: receita bate com a silver": receita_bate("gold.vendas_temporais"),
    "gold.vendas_produtos: receita bate com a silver": receita_bate("gold.vendas_produtos"),
    "gold.clientes_segmentacao: receita bate com a silver": receita_bate("gold.clientes_segmentacao"),
    "gold.vendas_detalhadas: receita bate com a silver": receita_bate("gold.vendas_detalhadas"),
    "gold.vendas_detalhadas: mesmo número de vendas da silver":
        "SELECT 1 FROM (SELECT COUNT(*) AS n FROM silver.vendas) s, "
        "(SELECT COUNT(*) AS n FROM gold.vendas_detalhadas) g WHERE s.n <> g.n",

    # Limite tolerado: o problema existe e é conhecido; o teste alerta se ele crescer
    "silver.vendas: produtos não cadastrados abaixo de 1% das vendas":
        "SELECT 1 FROM silver.vendas HAVING AVG(CASE WHEN produto_cadastrado THEN 0 ELSE 1 END) >= 0.01",

    # Documentação: o Genie (Aula 4) depende dos comentários para acertar o SQL
    "gold: toda coluna tem comentário":
        f"SELECT table_name, column_name FROM {catalogo}.information_schema.columns "
        "WHERE table_schema = 'gold' AND (comment IS NULL OR trim(comment) = '') "
        # tabelas internas que o pipeline cria para as materialized views
        "AND NOT startswith(table_name, '__materialization')",
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

# COMMAND ----------

# MAGIC %md
# MAGIC ## O placar de qualidade
# MAGIC
# MAGIC Os problemas conhecidos (e tolerados) não quebram o Job, mas continuam visíveis: a gold `qualidade_dados` mostra quantas linhas e quanta receita cada um afeta.

# COMMAND ----------

display(spark.table("gold.qualidade_dados"))
