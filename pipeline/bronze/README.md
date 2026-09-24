# Aula 2: Python & Engenharia de Dados

> **Objetivo do dia:** tirar o dado do **data lake** (o Storage do Supabase, que fala o protocolo S3 da AWS) e fazer ele chegar sozinho no Databricks, organizado em bronze → silver → gold, todo dia às 6h.

| | |
|---|---|
| **Esquenta** | [`00_esquenta_python.py`](./00_esquenta_python.py) (exercícios) e [`00_esquenta_python_gabarito.py`](./00_esquenta_python_gabarito.py) |
| **Aula** | [`01_ingestao_bronze.py`](./01_ingestao_bronze.py) (com lacunas) e [`01_ingestao_bronze_gabarito.py`](./01_ingestao_bronze_gabarito.py) |
| **Duração** | ~90 minutos |
| **Pré-requisito** | Aula 1 feita e **conta verificada** para acesso à internet |

## Roteiro

| Bloco | Tempo | O que acontece |
|---|---|---|
| Esquenta de Python | 20 min | Variáveis, listas, dicionários, `for`, funções, `requests` e `boto3` |
| Teoria | 15 min | Data lake, protocolo S3, camada bronze, ETL |
| Data lake → bronze | 30 min | Apagar o trabalho manual da Aula 1 e trazer os arquivos do storage |
| API do IBGE | 10 min | Uma segunda fonte, em JSON |
| Job de ingestão | 10 min | Agendar a chegada do dado para todo dia às 6h |

> **A aula termina na bronze.** Limpar, padronizar e criar as tabelas de negócio (silver e gold) é o trabalho da [Aula 3](../aula-03-claude-code/), feito com a ajuda do Claude Code.

---

## Parte 1: base teórica

### O problema da Aula 1

Você arrastou 4 arquivos CSV e respondeu os diretores. Funciona uma vez. Numa empresa de verdade:

- o dado **não está no seu computador**: está no storage da nuvem, exportado pelos sistemas;
- chega dado novo **o tempo todo**;
- alguém precisa garantir que o número do dashboard de amanhã está certo **sem ninguém olhar**.

Resolver isso é o trabalho da **engenharia de dados**.

### Onde o dado mora numa empresa

O sistema que roda a operação (o e-commerce, o ERP, o CRM) guarda tudo em um banco **transacional**: feito para gravar e ler poucas linhas por vez, muito rápido, milhares de vezes por segundo. Ninguém deixa um analista rodar `GROUP BY` em 10 milhões de linhas ali, porque a consulta pesada competiria com as compras acontecendo no site. É assim que um relatório derruba a loja.

A saída é o **data lake**: os sistemas exportam arquivos para um storage barato na nuvem, e a plataforma analítica lê de lá. Cada um faz o que faz bem.

```
 sistema (banco transacional) ──exporta──► data lake (arquivos) ──lê──► Databricks (análise)
```

### Object storage e o protocolo S3

O **S3** (*Simple Storage Service*) é o serviço de arquivos da AWS, e virou o padrão do mercado: quase todo storage na nuvem hoje aceita o mesmo protocolo, inclusive o **Storage do Supabase**, que é o nosso data lake. O vocabulário é curto:

| Termo | O que é | Aqui |
|---|---|---|
| **Bucket** | A pasta raiz, o "balde" | `Datalake` |
| **Key** | O caminho do arquivo dentro do bucket | `vendas.parquet` |
| **Endpoint** | O endereço do serviço | `https://<ref>.storage.supabase.co/storage/v1/s3` |
| **Access key / secret** | Usuário e senha da máquina | *Project Settings → Storage → S3 access keys* |

Não é um sistema de arquivos como o do seu computador: não existe "pasta" de verdade, e um arquivo não é alterado no meio. Você grava o objeto inteiro e lê o objeto inteiro. Isso é o que deixa o storage barato e praticamente infinito.

### boto3: a biblioteca de S3

```python
import boto3

s3 = boto3.client(
    "s3",
    endpoint_url=S3_ENDPOINT,
    region_name=S3_REGION,
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
)

s3.list_buckets()                                          # conferir a conexão
s3.list_objects_v2(Bucket="Datalake")                      # o que existe no bucket
s3.get_object(Bucket="Datalake", Key="vendas.parquet")     # baixar um arquivo
```

O `boto3` é da AWS, mas o `endpoint_url` faz ele falar com qualquer storage compatível. O código que você escreve hoje funciona igual na Amazon.

### A credencial na aula e na vida real

Na aula, a chave fica visível no notebook: são quatro linhas, e é o que deixa a explicação simples.

```python
ACCESS_KEY = "XXXX"
SECRET_KEY = "XXXX"
```

Em um projeto de verdade isso não acontece, porque notebook vai para o Git e credencial em repositório é incidente de segurança. O lugar certo é o **secret scope** do Databricks:

```bash
databricks secrets create-scope imersao
databricks secrets put-secret imersao s3_key
```

Aí o notebook lê com `dbutils.secrets.get("imersao", "s3_key")`, e o Databricks troca o valor por `[REDACTED]` em qualquer saída impressa. Essa troca é um dos assuntos da Aula 3.

### ETL e ELT

| Sigla | Ordem | Onde transforma |
|---|---|---|
| **ETL** | Extrai → Transforma → Carrega | Fora do destino, antes de gravar |
| **ELT** | Extrai → Carrega → Transforma | Dentro do destino, depois de gravar |

Em um lakehouse o padrão é **ELT**: primeiro guardamos o dado bruto (é barato e permite reprocessar), depois transformamos com o poder da própria plataforma.

### Arquitetura medalhão

```
 Origem ──► BRONZE ──────────► SILVER ─────────────► GOLD
 data lake  como chegou        limpo e confiável      pronto para o negócio
 + API      + quando chegou    tipos certos           uma tabela por pergunta
            + de onde veio     sem duplicatas         regras de negócio
                               problemas marcados
```

| Camada | Pergunta que ela responde | Quando |
|---|---|---|
| **Bronze** | "O que exatamente chegou?" | **Hoje.** `bronze.vendas`, `bronze.produtos`, `bronze.clientes`, `bronze.preco_competidores` e `bronze.estados_ibge` |
| **Silver** | "Posso confiar neste dado?" | Aula 3 |
| **Gold** | "Qual a resposta para o diretor?" | Aula 3 |

Hoje a regra é simples: **a bronze não limpa nada**. Ela guarda o dado como chegou, com a marca de quando chegou. Qualquer correção feita aqui apagaria a evidência do que a origem mandou.

**Por que não fazer tudo de uma vez?** Porque, quando algo der errado (e vai dar), você sabe em qual camada procurar e reprocessa a partir da bronze, sem precisar baixar tudo da origem de novo.

### Idempotência

Um pipeline é **idempotente** quando rodá-lo duas vezes dá o mesmo resultado que rodá-lo uma. Isso permite reexecutar sem medo depois de uma falha. No código isso aparece como `CREATE ... IF NOT EXISTS` para a estrutura e `mode("overwrite")` para os dados.

### Por que guardar uma cópia em Parquet

Os arquivos do data lake já são **Parquet**: formato colunar, comprimido e que guarda os tipos. Antes de transformar, o pipeline copia cada um para o volume, sem alterar nada.

| | CSV | Parquet |
|---|---|---|
| Guarda o tipo de cada coluna | Não (tudo é texto) | Sim |
| Tamanho (`vendas`) | 272 KB | 70 KB |
| Leitura de poucas colunas | Lê o arquivo inteiro | Lê só as colunas pedidas |

Com essa cópia no volume, reprocessar não exige baixar tudo de novo da origem.

### Spark e PySpark

O **Apache Spark** processa dados distribuindo o trabalho entre várias máquinas; o **PySpark** é o Spark a partir do Python. Três ideias:

1. **DataFrame:** uma tabela com colunas nomeadas e tipadas. Parecido com o pandas, mas feito para dados que não cabem em uma máquina.
2. **Transformações são preguiçosas:** `withColumn`, `join` e `filter` só montam um plano; nada roda até uma **ação** (`count`, `display`, `saveAsTable`).
3. **SQL e PySpark são o mesmo motor:** escolha o que deixa o código mais claro.

> **pandas ou PySpark?** O pandas trabalha na memória de uma máquina e é ótimo para inspecionar o arquivo que acabou de chegar. O PySpark escala para bilhões. Aqui usamos pandas na ingestão e PySpark da bronze em diante, que é o caminho natural quando o volume cresce.

### Serverless e Jobs

**Serverless** significa que você não gerencia máquinas. Um **Job** é um conjunto de tarefas com ordem de dependência (um **DAG**):

```
ingestao_bronze ──► silver ──► gold
```

Se a silver falhar, a gold nem começa, e ninguém vê número errado. O Job roda em um agendamento (expressão cron) e manda e-mail se falhar.

---

## Parte 2: passo a passo

### 0. Antes de começar

**Acesso à internet.** A Free Edition só acessa serviços externos com a conta **verificada**. Se a conexão falhar (`ConnectionError`, `Max retries exceeded`), verifique a conta pelo LinkedIn quando o Databricks pedir.

**O data lake.** Você precisa de um bucket com os 4 arquivos Parquet (`vendas`, `produtos`, `clientes` e `preco_competidores`), que estão na pasta [`dados/`](../dados/). No Supabase:

1. **Storage → New bucket**, nome `Datalake`.
2. Faça upload dos 4 arquivos `.parquet`.
3. **Project Settings → Storage → S3 access keys → New access key**. Guarde as duas partes.
4. Anote o endpoint, que aparece na mesma tela: `https://<ref>.storage.supabase.co/storage/v1/s3`.
5. Cole endpoint, região, chave e segredo nas variáveis do topo do notebook.

> **Plano B:** se o storage cair no meio da aula, os mesmos 4 arquivos Parquet estão na pasta [`dados/`](../dados/) do repositório e podem ser enviados direto ao volume pela interface. O gabarito mostra o caminho completo, então dá para seguir a explicação mesmo sem rodar.

### 1. Esquenta de Python (20 min)

Abra [`00_esquenta_python.py`](./00_esquenta_python.py) e resolva os 10 exercícios: variáveis, listas, dicionários, `for`, `if`, funções, `requests` com a API do IBGE, pandas, `boto3` no Storage do Supabase e escrita de arquivos no volume. As respostas comentadas estão no [gabarito](./00_esquenta_python_gabarito.py).

### 2. Data lake → bronze

Abra [`01_ingestao_bronze.py`](./01_ingestao_bronze.py), conecte em **Serverless** e siga célula por célula. Como no esquenta, as configurações já vêm prontas e o que falta é o código de cada etapa: criar o cliente, listar os buckets, baixar o arquivo, transformar em DataFrame e gravar a bronze. O [gabarito](./01_ingestao_bronze_gabarito.py) tem tudo escrito, para conferir depois (é ele que o Job executa).

O notebook começa **apagando** as tabelas que você subiu na mão na Aula 1. É proposital: no fim, elas voltam vindas do data lake, com a marca de quando e de onde chegaram.

No fim, a conferência deve mostrar:

| Tabela | Linhas |
|---|---:|
| `bronze.vendas` | 3.020 |
| `bronze.produtos` | 215 |
| `bronze.clientes` | 50 |
| `bronze.preco_competidores` | 728 |
| `bronze.estados_ibge` | 27 |

### 3. Agende a ingestão

1. **Jobs & Pipelines → Create → Job**, nome `Pipeline E-commerce`.
2. Tarefa `ingestao_bronze`: notebook `01_ingestao_bronze_gabarito`, compute **Serverless**.
3. O notebook não usa parâmetros: o catálogo e o bucket estão nas constantes do topo.
4. **Schedules & Triggers → Scheduled**: todo dia às 06:00, fuso `America/Sao_Paulo`.
5. Em **Notifications**, coloque seu e-mail para falhas.
6. **Run now** e veja a tarefa ficar verde.

Amanhã este Job ganha as tarefas de silver, gold e testes, e deixa de ser clicado na interface: vira um arquivo versionado no Git.

---

## Erros comuns

| Erro | Causa | Como resolver |
|---|---|---|
| `EndpointConnectionError` | Endpoint errado ou sem internet | Confira o endereço do Storage e a verificação da conta |
| `InvalidAccessKeyId` / `SignatureDoesNotMatch` | Chave ou segredo errados | Gere outra chave no Supabase e cole de novo |
| `NoSuchBucket` | Nome do bucket errado | Confira o nome usado no `list_objects_v2` |
| `KeyError: 'Contents'` | Bucket vazio | Faça o upload dos 4 Parquet |
| `NoSuchKey` | Nome do arquivo diferente | Os arquivos precisam se chamar `vendas.parquet`, `produtos.parquet`… |
| `EndpointConnectionError` logo na primeira célula | `S3_ENDPOINT` com erro de digitação | Confira a constante no topo do notebook |
| `ConnectionError` na API do IBGE | Conta não verificada | Verifique a conta pelo LinkedIn quando o Databricks pedir |
| `ModuleNotFoundError: boto3` | Biblioteca ausente | Rode `%pip install boto3` na primeira célula |
| Contagem diferente da esperada | Arquivo do bucket desatualizado | Refaça o upload dos Parquet e rode de novo |

---

## Para praticar

1. Baixe só os arquivos que mudaram desde a última execução, comparando o `LastModified` que o `list_objects_v2` devolve. É o começo da **carga incremental**.
2. Acrescente à silver uma coluna `faixa_horaria` (madrugada, manhã, tarde e noite) e leve para a gold.
3. Consuma outra API pública (por exemplo, a cotação do dólar em `economia.awesomeapi.com.br`) e grave na bronze.
4. Use o `put_object` do `boto3` para devolver ao bucket um arquivo gerado por você, por exemplo a gold em Parquet.

## Amanhã

O dado chega sozinho, mas chega **cru**: preço como número quebrado, data como texto, venda de produto que não existe no catálogo. Ninguém entrega isso para um diretor.

Na [Aula 3](../aula-03-claude-code/) você constrói as camadas **silver** e **gold** com a ajuda do Claude Code, escreve testes que param o Job quando o dado está errado e faz o deploy do projeto inteiro com um comando.
