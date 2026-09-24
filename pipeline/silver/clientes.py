# Silver · clientes
#
# Dois cuidados com o cliente:
# - 11 dos 50 nomes chegam com pronome de tratamento ("Sr.", "Dra."...). O nome limpo
#   agrupa e ordena melhor; o original fica guardado em `nome_original`.
# - O cliente só tem a UF. A API do IBGE (bronze.estados_ibge) traz o nome do estado e a
#   região, que a diretoria de Customer Success usa para dividir a carteira.

from pyspark import pipelines as dp
from pyspark.sql import functions as F

TRATAMENTO = r"^(Sr|Sra|Srta|Dr|Dra)\.\s+"


@dp.materialized_view(comment="Clientes com nome limpo, UF padronizada e região do IBGE.")
@dp.expect_all_or_fail({
    "id_cliente_preenchido": "id_cliente IS NOT NULL",
    # UF que não existe no IBGE ficaria sem região e sumiria dos gráficos por região
    "cliente_com_regiao": "regiao IS NOT NULL",
})
def clientes():
    estados = spark.read.table("bronze.estados_ibge").select(
        F.col("sigla").alias("estado"),
        F.col("nome").alias("nome_estado"),
        F.col("regiao_nome").alias("regiao"),
    )

    return (
        spark.read.table("bronze.clientes")
        .dropDuplicates(["id_cliente"])
        .withColumn("nome_original", F.trim("nome_cliente"))
        .withColumn("nome_cliente", F.initcap(F.regexp_replace("nome_original", TRATAMENTO, "")))
        .withColumn("estado", F.upper(F.trim("estado")))
        .join(estados, on="estado", how="left")
    )
