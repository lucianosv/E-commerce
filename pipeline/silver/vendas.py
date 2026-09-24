# Silver · vendas
#
# A tabela mais importante. Aqui:
# 1. o preço vira DECIMAL e nasce a receita (quantidade × preço unitário);
# 2. a data é quebrada em dia, hora e dia da semana (os diretores perguntam "que dia vende mais?");
# 3. dois problemas de qualidade são MARCADOS, nunca apagados:
#    - produto_cadastrado = false: 20 vendas de produtos que não estão no catálogo (Aula 1);
#    - venda_antes_do_cadastro = true: 5 vendas anteriores à criação do produto.
#    Dinheiro que entrou é receita. Apagar essas vendas mudaria o faturamento.
#
# Expectations:
# - `expect_all_or_fail`: o que nunca pode acontecer (chave vazia, quantidade negativa, canal
#   desconhecido). Se acontecer, o pipeline para antes de a gold mostrar número errado.
# - `expect` (warn): problema conhecido e tolerado. A linha passa, e a métrica aparece no
#   event log do pipeline a cada execução.

from pyspark import pipelines as dp
from pyspark.sql import functions as F

DINHEIRO = "decimal(10,2)"

DIAS = {
    "Sunday": "Domingo", "Monday": "Segunda", "Tuesday": "Terça", "Wednesday": "Quarta",
    "Thursday": "Quinta", "Friday": "Sexta", "Saturday": "Sábado",
}
TRADUCAO = F.create_map([F.lit(x) for par in DIAS.items() for x in par])


@dp.materialized_view(comment="Uma linha por venda, com receita, calendário e marcações de qualidade.")
@dp.expect_all_or_fail({
    "campos_obrigatorios": "id_venda IS NOT NULL AND data_venda IS NOT NULL AND id_cliente IS NOT NULL "
                           "AND id_produto IS NOT NULL AND quantidade IS NOT NULL AND preco_unitario IS NOT NULL",
    "quantidade_positiva": "quantidade > 0",
    "preco_positivo": "preco_unitario > 0",
    "canal_conhecido": "canal_venda IN ('ecommerce', 'loja_fisica')",
})
@dp.expect_all({
    "produto_cadastrado": "produto_cadastrado",
    "venda_depois_do_cadastro": "NOT venda_antes_do_cadastro",
})
def vendas():
    cadastro = spark.read.table("silver.produtos").select(
        "id_produto", F.lit(True).alias("produto_cadastrado"), "data_criacao"
    )

    return (
        spark.read.table("bronze.vendas")
        .dropDuplicates(["id_venda"])
        .withColumn("preco_unitario", F.col("preco_unitario").cast(DINHEIRO))
        .withColumn("receita", (F.col("quantidade") * F.col("preco_unitario")).cast(DINHEIRO))
        .withColumn("data", F.to_date("data_venda"))
        .withColumn("hora", F.hour("data_venda"))
        .withColumn("dia_semana_num", F.dayofweek("data_venda"))  # 1 = domingo ... 7 = sábado
        .withColumn("dia_semana", TRADUCAO[F.date_format("data_venda", "EEEE")])
        .join(cadastro, on="id_produto", how="left")
        .withColumn("produto_cadastrado", F.coalesce("produto_cadastrado", F.lit(False)))
        .withColumn(
            "venda_antes_do_cadastro",
            F.coalesce(F.col("data_venda") < F.col("data_criacao"), F.lit(False)),
        )
        .drop("data_criacao")
    )
