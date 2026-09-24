# Databricks notebook source
# MAGIC %md
# MAGIC # Aula 2 · Esquenta de Python
# MAGIC ### Tudo o que você precisa saber antes do pipeline
# MAGIC
# MAGIC Hoje o dado vai sair do **data lake** (o Storage do Supabase, que fala o protocolo S3) e chegar no
# MAGIC Databricks. Para isso você vai usar Python em cinco situações, e este notebook treina essas cinco.
# MAGIC
# MAGIC | # | O que você vai treinar | Onde isso aparece na aula |
# MAGIC |---|---|---|
# MAGIC | 1 | Variáveis e tipos | Guardar o endpoint, o bucket, o nome do arquivo |
# MAGIC | 2 | Listas | A lista das 4 tabelas que o pipeline processa |
# MAGIC | 3 | Dicionários | A resposta de uma API vira dicionário |
# MAGIC | 4 | `for` e funções | Repetir a mesma ingestão para cada arquivo |
# MAGIC | 5 | Bibliotecas | `requests` (API), `boto3` (arquivos no S3), `pandas` (tabelas) |
# MAGIC
# MAGIC **Como usar:** cada célula tem um objetivo e um espaço para você escrever. Tente sozinho primeiro. O
# MAGIC notebook `00_esquenta_python_gabarito` tem todas as respostas comentadas.
# MAGIC
# MAGIC > Nunca programou em Python? Sem problema. Os exercícios 1 a 6 são de aquecimento e levam 15 minutos.

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Variáveis e tipos
# MAGIC
# MAGIC Em Python você guarda um valor em um nome, sem declarar o tipo. O `type()` mostra o que o Python entendeu.
# MAGIC
# MAGIC | Tipo | O que guarda | Exemplo |
# MAGIC |---|---|---|
# MAGIC | `str` | Texto | `"vendas"` |
# MAGIC | `int` | Número inteiro | `3020` |
# MAGIC | `float` | Número com decimais | `974077.28` |
# MAGIC | `bool` | Verdadeiro ou falso | `True` |
# MAGIC
# MAGIC **Objetivo:** criar uma variável de cada tipo e imprimir o valor e o tipo de cada uma.

# COMMAND ----------

nome_tabela = "vendas"
total_vendas = 3020
# escreva seu código aqui: crie receita_total (float) e pipeline_ativo (bool)


print(nome_tabela, type(nome_tabela))
print(total_vendas, type(total_vendas))

# COMMAND ----------

# MAGIC %md
# MAGIC ### f-string: juntando texto e variável
# MAGIC
# MAGIC A letra `f` antes das aspas permite colocar variáveis dentro do texto, entre chaves.
# MAGIC
# MAGIC **Objetivo:** imprimir a frase `A tabela vendas tem 3020 linhas.` usando as variáveis acima.

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Listas
# MAGIC
# MAGIC Uma lista guarda vários valores em ordem, entre colchetes. O primeiro item é o de posição `0`.
# MAGIC
# MAGIC **Objetivo:** criar a lista com as 4 tabelas do projeto, imprimir quantas são e mostrar a primeira e a última.

# COMMAND ----------

# escreva seu código aqui: tabelas = [...]
# dicas: len(lista) conta os itens; lista[0] é o primeiro; lista[-1] é o último


# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Dicionários
# MAGIC
# MAGIC Um dicionário guarda pares **chave: valor**, entre chaves. É assim que os dados de uma API chegam.
# MAGIC
# MAGIC ```python
# MAGIC produto = {"nome": "Edredom Casal", "categoria": "Casa", "preco": 189.90}
# MAGIC produto["nome"]   # devolve "Edredom Casal"
# MAGIC ```
# MAGIC
# MAGIC **Objetivo:** criar o dicionário `venda` com as chaves `id_venda`, `canal`, `quantidade` e `preco_unitario`,
# MAGIC e imprimir a receita da venda (quantidade × preço).

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ### Dicionário dentro de dicionário
# MAGIC
# MAGIC APIs costumam devolver estruturas aninhadas. Para chegar no valor de dentro, encadeie os colchetes.
# MAGIC
# MAGIC **Objetivo:** a partir do dicionário abaixo, imprimir apenas o nome da região (`Norte`).

# COMMAND ----------

estado = {"sigla": "AM", "nome": "Amazonas", "regiao": {"id": 1, "sigla": "N", "nome": "Norte"}}

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. `for`: repetindo o mesmo passo
# MAGIC
# MAGIC O `for` percorre uma lista e executa o mesmo bloco para cada item. Repare na **indentação**: o que está
# MAGIC dentro do laço fica deslocado quatro espaços à direita.
# MAGIC
# MAGIC **Objetivo:** percorrer a lista de tabelas e imprimir, para cada uma, a frase
# MAGIC `Baixando vendas.parquet do data lake...`

# COMMAND ----------

tabelas = ["vendas", "produtos", "clientes", "preco_competidores"]

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ### `if`: decidindo no meio do caminho
# MAGIC
# MAGIC **Objetivo:** percorrer a lista `quantidades` e imprimir `venda grande` quando o valor for maior que 2,
# MAGIC e `venda pequena` caso contrário.

# COMMAND ----------

quantidades = [1, 3, 2, 5, 1]

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Funções
# MAGIC
# MAGIC Uma função é um bloco com nome, que recebe dados (parâmetros) e devolve um resultado (`return`). É o que
# MAGIC evita copiar e colar o mesmo código quatro vezes.
# MAGIC
# MAGIC ```python
# MAGIC def dobro(numero):
# MAGIC     return numero * 2
# MAGIC
# MAGIC dobro(10)   # devolve 20
# MAGIC ```
# MAGIC
# MAGIC **Objetivo:** escrever a função `calcular_receita(quantidade, preco_unitario)` que devolve a receita
# MAGIC arredondada em 2 casas, e testá-la com 2 unidades de R$ 64,79 (deve devolver `129.58`).

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Bibliotecas
# MAGIC
# MAGIC Biblioteca é código pronto que alguém escreveu. Você importa e usa. As quatro de hoje:
# MAGIC
# MAGIC | Biblioteca | Serve para |
# MAGIC |---|---|
# MAGIC | `requests` | Conversar com APIs pela internet |
# MAGIC | `pandas` | Trabalhar com tabelas em memória (DataFrame) |
# MAGIC | `boto3` | Ler e gravar arquivos em storage compatível com S3 |
# MAGIC | `io` | Tratar bytes da memória como se fossem arquivo |
# MAGIC
# MAGIC **Objetivo:** importar `requests` e `pandas` e imprimir a versão do pandas (`pd.__version__`).

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Consumindo uma API
# MAGIC
# MAGIC Uma **API** é uma porta que um sistema abre para outros pedirem dados. Você faz uma requisição HTTP `GET`
# MAGIC em uma URL e recebe a resposta, quase sempre em **JSON**, que em Python vira lista e dicionário.
# MAGIC
# MAGIC Vamos usar a API pública do IBGE, que devolve os 27 estados brasileiros com a sua região:
# MAGIC
# MAGIC ```
# MAGIC GET https://servicodados.ibge.gov.br/api/v1/localidades/estados
# MAGIC ```
# MAGIC
# MAGIC **Objetivo:** fazer a requisição, conferir se o status é `200` (deu certo), transformar em lista de
# MAGIC dicionários com `.json()` e imprimir quantos estados vieram e o primeiro deles.
# MAGIC
# MAGIC > Se der erro de conexão, sua conta do Databricks ainda não foi verificada. Veja o `README.md` desta pasta.

# COMMAND ----------

import requests

URL_IBGE = "https://servicodados.ibge.gov.br/api/v1/localidades/estados"

# escreva seu código aqui: resposta = requests.get(...), veja resposta.status_code e resposta.json()


# COMMAND ----------

# MAGIC %md
# MAGIC **Objetivo:** montar uma lista de dicionários só com `sigla`, `nome` e o nome da **região** de cada estado,
# MAGIC e transformar em um DataFrame do pandas com `pd.DataFrame(lista)`.

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. pandas: a tabela em memória
# MAGIC
# MAGIC Um **DataFrame** é uma tabela: tem colunas com nome e tipo. Comandos que você vai usar sempre:
# MAGIC
# MAGIC | Comando | O que faz |
# MAGIC |---|---|
# MAGIC | `df.head()` | Primeiras linhas |
# MAGIC | `df.shape` | (linhas, colunas) |
# MAGIC | `df.columns` | Nomes das colunas |
# MAGIC | `df["coluna"]` | Uma coluna |
# MAGIC | `df[df["coluna"] > 10]` | Filtro (o `WHERE` do SQL) |
# MAGIC | `df.groupby("col")["outra"].sum()` | Agrupar e somar (o `GROUP BY` do SQL) |
# MAGIC
# MAGIC **Objetivo:** com o DataFrame de estados, contar quantos estados existem em cada região.

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 9. boto3: lendo arquivos do data lake
# MAGIC
# MAGIC O **boto3** é a biblioteca da AWS para falar com o **S3**, o serviço de arquivos na nuvem. O Storage do
# MAGIC **Supabase** fala o mesmo protocolo, então o mesmo código serve para os dois: muda só o `endpoint_url`.
# MAGIC
# MAGIC | Termo | O que é |
# MAGIC |---|---|
# MAGIC | **Bucket** | A pasta raiz, o "balde" |
# MAGIC | **Key** | O caminho do arquivo dentro do bucket, por exemplo `vendas.parquet` |
# MAGIC | **Endpoint** | O endereço do serviço |
# MAGIC | **Access key / secret** | Usuário e senha da máquina |
# MAGIC
# MAGIC > Na aula a chave fica no notebook, para ser simples de ver. Em produção ela sai daqui e vai para o
# MAGIC > secret scope do Databricks, o que entra na Aula 3.

# COMMAND ----------

# Objetivo: criar o cliente S3 e listar os buckets, para conferir que a conexão funciona.
# Dica: s3.list_buckets() devolve um dicionário; os buckets estão em ["Buckets"], cada um com "Name".

import boto3

# copie do Supabase: Project Settings → Storage → S3 access keys
S3_ENDPOINT = "https://pnkfrnjvvywiufphcqgw.storage.supabase.co/storage/v1/s3"
S3_REGION = "us-east-2"
S3_BUCKET = "ecommerce"

ACCESS_KEY = "XXXX"
SECRET_KEY = "XXXX"

# escreva seu código aqui: s3 = boto3.client(...) e depois liste os buckets


# COMMAND ----------

# MAGIC %md
# MAGIC **Objetivo:** listar os arquivos do bucket `ecommerce`, imprimindo o nome e o tamanho de cada um.
# MAGIC
# MAGIC Dica: `s3.list_objects_v2(Bucket=S3_BUCKET)["Contents"]`, onde cada item tem `"Key"` e `"Size"`.

# COMMAND ----------

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## 10. De bytes para tabela
# MAGIC
# MAGIC O `get_object` devolve um dicionário; o conteúdo está em `Body`, e o `.read()` transforma em **bytes**.
# MAGIC O pandas espera um arquivo, e o que temos são bytes na memória: o `io.BytesIO` finge ser um arquivo.
# MAGIC
# MAGIC **Objetivo:** baixar `vendas.parquet`, imprimir quantos bytes vieram, transformar em DataFrame e mostrar
# MAGIC as primeiras linhas.

# COMMAND ----------

import io

# escreva seu código aqui


# COMMAND ----------

# MAGIC %md
# MAGIC ## Fechando o esquenta
# MAGIC
# MAGIC Se você resolveu os 10 exercícios, tem tudo o que precisa para a aula:
# MAGIC
# MAGIC - sabe guardar valores e percorrer listas;
# MAGIC - entende a resposta de uma API e a de um storage S3;
# MAGIC - sabe transformar bytes em tabela com o pandas;
# MAGIC - conhece as bibliotecas que o pipeline usa.
# MAGIC
# MAGIC Siga para o **`01_ingestao_bronze`**, onde os arquivos do data lake viram tabelas no Databricks.
