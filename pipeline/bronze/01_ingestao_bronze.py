# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# MAGIC %md
# MAGIC # Aula 2 · Data lake → Bronze
# MAGIC ### "De onde vieram esses dados?"
# MAGIC
# MAGIC Na Aula 1 você arrastou 4 arquivos CSV para dentro do Databricks. Funciona uma vez. Mas numa empresa os
# MAGIC arquivos não ficam no seu computador: eles ficam em um **storage na nuvem**, e chegam lá todo dia.
# MAGIC
# MAGIC O nosso data lake é o **Storage do Supabase**, que fala o mesmo protocolo do **Amazon S3**. O código que
# MAGIC você escreve hoje funciona igual na AWS.
# MAGIC
# MAGIC ```
# MAGIC  Datalake (S3)              tabelas
# MAGIC  clientes.parquet    ──►    ecommerce.bronze.clientes
# MAGIC  produtos.parquet           ecommerce.bronze.produtos
# MAGIC  vendas.parquet             ecommerce.bronze.vendas
# MAGIC  preco_competidores.parquet ecommerce.bronze.preco_competidores
# MAGIC ```
# MAGIC
# MAGIC **Como usar:** cada célula diz o objetivo e dá a dica; o código é você quem escreve. Se travar, o
# MAGIC `01_ingestao_bronze_gabarito` tem tudo pronto.

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Conectando no storage
# MAGIC
# MAGIC Copie os valores do Supabase em **Project Settings → Storage → S3 access keys**. Se os buckets
# MAGIC aparecerem, a conexão está certa.

# COMMAND ----------

# MAGIC %pip install boto3

# COMMAND ----------

import boto3

S3_ENDPOINT = "https://zuypcqdkhxupvipjscwp.storage.supabase.co/storage/v1/s3"
S3_REGION = "sa-east-1"

ACCESS_KEY = "e792be9acd9e3d5c76905105839272d8"
SECRET_KEY = "ace06e4358df5b237fe86808c4f2011b489dd4ca34b4e95d7232e573c0fc921f"

# Objetivo: criar o cliente e listar os buckets.
# Dica: boto3.client("s3", endpoint_url=..., region_name=..., aws_access_key_id=..., aws_secret_access_key=...)
#       s3.list_buckets()["Buckets"] é uma lista de dicionários, cada um com "Name".

s3 = boto3.client("s3", endpoint_url=S3_ENDPOINT, region_name=S3_REGION, aws_access_key_id=ACCESS_KEY, aws_secret_access_key=SECRET_KEY)
s3.list_buckets()["Buckets"]


# COMMAND ----------

# MAGIC %md
# MAGIC | Termo | O que é |
# MAGIC |---|---|
# MAGIC | **Bucket** | A pasta raiz, o "balde" |
# MAGIC | **Key** | O caminho do arquivo dentro do bucket, por exemplo `vendas.parquet` |
# MAGIC | **Endpoint** | O endereço do serviço |
# MAGIC | **Access key / secret** | Usuário e senha da máquina |
# MAGIC
# MAGIC > Na aula a chave fica no notebook, para ser simples de ver. Em produção ela sai daqui e vai para o
# MAGIC > secret scope do Databricks, o que entra na Aula 3.
# MAGIC
# MAGIC ## 2. O que tem dentro do bucket

# COMMAND ----------

# Objetivo: listar os arquivos do bucket Datalake.
# Dica: s3.list_objects_v2(Bucket="Datalake") devolve um dicionário; os arquivos estão em "Contents",
#       e cada um tem "Key".

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Baixando um arquivo
# MAGIC
# MAGIC Três passos, e cada um é uma linha:
# MAGIC
# MAGIC 1. `get_object` devolve um dicionário; o conteúdo está em `Body`, e o `.read()` transforma em **bytes**;
# MAGIC 2. o pandas espera um arquivo, então o `io.BytesIO` finge ser um arquivo para ele ler os bytes;
# MAGIC 3. o `spark.createDataFrame` converte o DataFrame do pandas em DataFrame do Spark, que sabe gravar tabela.

# COMMAND ----------

# Objetivo: baixar clientes.parquet e chegar em um DataFrame do Spark chamado df_clientes.
# Dicas: s3.get_object(Bucket=..., Key=...)["Body"].read() devolve bytes;
#        pd.read_parquet(io.BytesIO(...)) devolve um DataFrame do pandas;
#        spark.createDataFrame(pdf) converte para Spark.

import io
import pandas as pd

# escreva seu código aqui


# COMMAND ----------

display(df_clientes)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Gravando na bronze
# MAGIC
# MAGIC Antes, a estrutura. Aproveitamos para **apagar as tabelas que você subiu na mão na Aula 1**: elas voltam
# MAGIC agora vindas do data lake.

# COMMAND ----------

# Objetivo: criar o catálogo e o schema bronze e apagar as 4 tabelas da Aula 1.
# Dica: spark.sql("...") roda SQL pelo Python; use CREATE ... IF NOT EXISTS e DROP TABLE IF EXISTS.

# escreva seu código aqui


# COMMAND ----------

# Objetivo: gravar df_clientes como ecommerce.bronze.clientes.
# Dica: df.write.format("delta").mode("overwrite").saveAsTable("...")

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Repetindo para as 4 tabelas
# MAGIC
# MAGIC E se fossem 4, 10 ou 100 arquivos? Copiar o bloco acima 100 vezes é pedir para errar. O `for` repete o
# MAGIC mesmo caminho para cada tabela.

# COMMAND ----------

# Objetivo: repetir baixar, ler e gravar para as 4 tabelas.

for tabela in ["vendas", "produtos", "clientes", "preco_competidores"]:
    # escreva seu código aqui
    pass

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Uma fonte a mais: a API do IBGE
# MAGIC
# MAGIC A Diretora de Customer Success pediu a visão **por região**, mas o cadastro de clientes só tem a UF.
# MAGIC Nenhum arquivo do data lake resolve: o dado está fora da empresa.
# MAGIC
# MAGIC O padrão é o mesmo: buscar na origem, virar DataFrame, gravar na bronze.

# COMMAND ----------

import requests

URL_IBGE = "https://servicodados.ibge.gov.br/api/v1/localidades/estados"

# Objetivo: chamar a API e guardar a resposta em `estados`.
# Dica: requests.get(URL_IBGE, timeout=60).json()

# escreva seu código aqui


print(f"{len(estados)} estados recebidos. Exemplo:")
print(estados[0])

# COMMAND ----------

# MAGIC %md
# MAGIC O JSON tem um dicionário dentro do outro (`regiao`). O `pd.json_normalize` achata isso e transforma
# MAGIC `regiao.nome` em coluna.

# COMMAND ----------

# Objetivo: achatar o JSON e gravar ecommerce.bronze.estados_ibge.

pdf = pd.json_normalize(estados)
pdf.columns = [coluna.replace(".", "_") for coluna in pdf.columns]

# escreva seu código aqui


display(spark.table("ecommerce.bronze.estados_ibge"))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Conferência

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT 'vendas' AS tabela, COUNT(*) AS linhas FROM ecommerce.bronze.vendas
# MAGIC UNION ALL SELECT 'produtos', COUNT(*) FROM ecommerce.bronze.produtos
# MAGIC UNION ALL SELECT 'clientes', COUNT(*) FROM ecommerce.bronze.clientes
# MAGIC UNION ALL SELECT 'preco_competidores', COUNT(*) FROM ecommerce.bronze.preco_competidores
# MAGIC UNION ALL SELECT 'estados_ibge', COUNT(*) FROM ecommerce.bronze.estados_ibge

# COMMAND ----------

# MAGIC %md
# MAGIC Esperado: 3.020 vendas, 215 produtos, 50 clientes, 728 preços de concorrentes e 27 estados.
# MAGIC
# MAGIC ### O que você construiu aqui
# MAGIC
# MAGIC - Uma ingestão que **não depende de ninguém arrastar arquivo**.
# MAGIC - Duas fontes diferentes (um data lake S3 e uma API) virando tabela do mesmo jeito.
# MAGIC
# MAGIC Confira o seu código com o **`01_ingestao_bronze_gabarito`**.
# MAGIC
# MAGIC **Amanhã:** a Aula 3 limpa e organiza esse dado nas camadas silver e gold, com a ajuda do Claude Code, e
# MAGIC tira a chave de dentro do notebook.