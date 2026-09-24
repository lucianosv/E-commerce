# Silver · produtos
#
# A bronze é fiel à origem; a silver é o dado em que dá para confiar. Aqui:
# - o preço sai de double (ponto flutuante) para DECIMAL(10,2), o tipo certo para dinheiro;
# - nasce a faixa de preço, usada pela gold e pelo dashboard.
#
# Por que materialized view e não streaming table? A ingestão da Aula 2 sobrescreve a bronze
# a cada execução. Uma MV relê a fonte inteira e recalcula; uma streaming table só aceitaria
# linhas novas e quebraria com a sobrescrita.
#
# Nomes como `bronze.produtos` não têm catálogo: resolvem no catálogo do pipeline
# (variável `catalogo` do bundle). As tabelas do schema padrão (silver) também podem ser
# lidas sem prefixo, mas escrevemos `silver.` para deixar a camada explícita.

from pyspark import pipelines as dp
from pyspark.sql import functions as F

DINHEIRO = "decimal(10,2)"


@dp.materialized_view(comment="Catálogo de produtos limpo: preço em DECIMAL e faixa de preço.")
@dp.expect_all_or_fail({
    "id_produto_preenchido": "id_produto IS NOT NULL",
    "preco_positivo": "preco_atual > 0",
})
def produtos():
    return (
        spark.read.table("bronze.produtos")
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
