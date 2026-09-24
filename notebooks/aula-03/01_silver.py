# Databricks notebook source
# MAGIC %md
# MAGIC # Aula 3 · Parte 1: Bronze → Silver
# MAGIC
# MAGIC A bronze é fiel à origem, com todos os defeitos. A **silver** é o dado em que dá para confiar:
# MAGIC
# MAGIC | Problema na bronze | O que a silver faz |
# MAGIC |---|---|
# MAGIC | `data_coleta` dos concorrentes chega como texto | Converte para `timestamp` |
# MAGIC | Preços em `double` (ponto flutuante) | Converte para `DECIMAL(10,2)`, o tipo certo para dinheiro |
# MAGIC | Receita não existe como coluna | Calcula `receita = quantidade × preco_unitario` |
# MAGIC | 20 vendas de produtos não cadastrados (lembra da Aula 1?) | Mantém a venda e marca `produto_cadastrado = false` |
# MAGIC | Cliente só tem a UF | Enriquece com nome do estado e região (API do IBGE) |
# MAGIC
# MAGIC **Por que PySpark aqui?** Limpeza é uma sequência de passos pequenos (converter, calcular, juntar, marcar). Em Python cada passo vira uma linha que dá para testar separado e reaproveitar em funções. As regras de negócio da gold ficam em SQL, que é a língua que o negócio já leu na Aula 1.
# MAGIC
# MAGIC > Na Aula 3 este notebook é o ponto de partida do trabalho com o Claude Code: você descreve a regra no PRD e revisa o que a IA escreve.

# COMMAND ----------

dbutils.widgets.text("catalogo", "ecommerce")
catalogo = dbutils.widgets.get("catalogo")

from pyspark.sql import DataFrame
from pyspark.sql import functions as F

DINHEIRO = "decimal(10,2)"


def bronze(tabela: str) -> DataFrame:
    """Lê uma tabela da camada bronze."""
    return spark.table(f"{catalogo}.bronze.{tabela}")


def gravar_silver(df: DataFrame, tabela: str) -> None:
    df.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(f"{catalogo}.silver.{tabela}")
    print(f"✅ {catalogo}.silver.{tabela:<20} {spark.table(f'{catalogo}.silver.{tabela}').count():>6,} linhas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Produtos
# MAGIC
# MAGIC Além de padronizar o preço, criamos a **faixa de preço**. `F.when` é o `CASE WHEN` do PySpark.

# COMMAND ----------

produtos = (
    bronze("produtos")
    .dropDuplicates(["id_produto"])
    .withColumn("nome_produto", F.trim("nome_produto"))
    .withColumn("preco_atual", F.col("preco_atual").cast(DINHEIRO))
    .withColumn(
        "faixa_preco",
        F.when(F.col("preco_atual") > 1000, "PREMIUM")
        .when(F.col("preco_atual") > 500, "MEDIO")
        .otherwise("BASICO"),
    )
)

display(produtos.groupBy("faixa_preco").count())
gravar_silver(produtos, "produtos")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Clientes + regiões do IBGE
# MAGIC
# MAGIC A ingestão já achatou o JSON do IBGE, então a região chegou como `regiao_nome`. Aqui só renomeamos
# MAGIC e juntamos pela UF.

# COMMAND ----------

estados = bronze("estados_ibge").select(
    F.col("sigla").alias("estado"),
    F.col("nome").alias("nome_estado"),
    F.col("regiao_nome").alias("regiao"),
)

clientes = (
    bronze("clientes")
    .dropDuplicates(["id_cliente"])
    .withColumn("nome_cliente", F.initcap(F.trim("nome_cliente")))
    .withColumn("estado", F.upper(F.trim("estado")))
    .join(estados, on="estado", how="left")
)

display(clientes.groupBy("regiao").count().orderBy(F.desc("count")))
gravar_silver(clientes, "clientes")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Preços dos concorrentes

# COMMAND ----------

preco_competidores = (
    bronze("preco_competidores")
    .dropDuplicates(["id_produto", "nome_concorrente"])
    .withColumn("preco_concorrente", F.col("preco_concorrente").cast(DINHEIRO))
    .withColumn("data_coleta", F.to_timestamp("data_coleta"))
)

preco_competidores.printSchema()
gravar_silver(preco_competidores, "preco_competidores")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Vendas
# MAGIC
# MAGIC A tabela mais importante. Aqui a gente:
# MAGIC 1. converte o preço para decimal e calcula a receita;
# MAGIC 2. quebra a data em dia, hora e dia da semana (os diretores vão perguntar "que dia vende mais?");
# MAGIC 3. marca as vendas de produtos que não estão no catálogo, **sem apagar nada**.

# COMMAND ----------

ids_produtos = spark.table(f"{catalogo}.silver.produtos").select("id_produto", F.lit(True).alias("produto_cadastrado"))

vendas = (
    bronze("vendas")
    .dropDuplicates(["id_venda"])
    .withColumn("preco_unitario", F.col("preco_unitario").cast(DINHEIRO))
    .withColumn("receita", (F.col("quantidade") * F.col("preco_unitario")).cast(DINHEIRO))
    .withColumn("data", F.to_date("data_venda"))
    .withColumn("hora", F.hour("data_venda"))
    .withColumn("dia_semana_num", F.dayofweek("data_venda"))  # 1 = domingo ... 7 = sábado
    .withColumn("dia_semana", F.date_format("data_venda", "EEEE"))
    .join(ids_produtos, on="id_produto", how="left")
    .withColumn("produto_cadastrado", F.coalesce("produto_cadastrado", F.lit(False)))
)

display(vendas.groupBy("produto_cadastrado").agg(F.count("*").alias("vendas"), F.sum("receita").alias("receita")))

# COMMAND ----------

# MAGIC %md
# MAGIC `date_format(..., "EEEE")` devolve o dia em inglês. Um dicionário resolve a tradução:

# COMMAND ----------

DIAS = {
    "Sunday": "Domingo", "Monday": "Segunda", "Tuesday": "Terça", "Wednesday": "Quarta",
    "Thursday": "Quinta", "Friday": "Sexta", "Saturday": "Sábado",
}
traducao = F.create_map([F.lit(x) for par in DIAS.items() for x in par])

vendas = vendas.withColumn("dia_semana", traducao[F.col("dia_semana")])

display(vendas.limit(5))
gravar_silver(vendas, "vendas")
