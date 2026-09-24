# Silver · preço dos concorrentes
#
# - `data_coleta` chega como texto; vira timestamp.
# - 55 preços são exatamente metade do nosso. Pode ser promoção de verdade ou erro de coleta:
#   a silver não decide, só marca `preco_suspeito`. A linha continua na tabela (os números de
#   referência dependem dela) e a expectation mede quantas são a cada execução.

from pyspark import pipelines as dp
from pyspark.sql import functions as F

DINHEIRO = "decimal(10,2)"

# Abaixo de 60% do nosso preço: nenhum concorrente legítimo aparece nessa faixa
# (os demais ficam entre 92% e 110%).
LIMITE_SUSPEITO = 0.6


@dp.materialized_view(comment="Preço de cada concorrente por produto, com marcação de preço suspeito.")
@dp.expect_all_or_fail({
    "id_produto_preenchido": "id_produto IS NOT NULL",
    "preco_positivo": "preco_concorrente > 0",
})
@dp.expect("preco_plausivel", "NOT preco_suspeito")
def preco_competidores():
    nosso_preco = spark.read.table("silver.produtos").select("id_produto", "preco_atual")

    return (
        spark.read.table("bronze.preco_competidores")
        .dropDuplicates(["id_produto", "nome_concorrente"])
        .withColumn("preco_concorrente", F.col("preco_concorrente").cast(DINHEIRO))
        .withColumn("data_coleta", F.to_timestamp("data_coleta"))
        .join(nosso_preco, on="id_produto", how="left")
        .withColumn(
            "preco_suspeito",
            F.coalesce(F.col("preco_concorrente") < F.col("preco_atual") * LIMITE_SUSPEITO, F.lit(False)),
        )
        .drop("preco_atual")
    )
