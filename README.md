# Aula 3: Claude Code, Databricks CLI e o pipeline declarativo

> **Objetivo do dia:** transformar o dado cru da bronze em tabelas em que o negócio confia (**silver** e **gold**) e fazer isso como profissional: um **pipeline declarativo** com regras de qualidade, código no Git, especificação escrita, testes que param o Job quando o dado está errado e deploy com um comando. Tudo com a IA como par de programação.

| | |
|---|---|
| **Pipeline** | [`pipeline/silver/`](./pipeline/silver/) (PySpark) e [`pipeline/gold/`](./pipeline/gold/) (SQL): um arquivo por tabela |
| **Testes** | [`testes/04_testes_qualidade`](./testes/04_testes_qualidade) |
| **Prompts** | [`prompts/`](./prompts/): a Aula 3 inteira em 4 prompts (`prompt_01.md` a `prompt_04.md`) |
| **Apoio** | [`PRD.md`](./PRD.md), [`CLAUDE.md`](./CLAUDE.md), [`databricks.yml`](../databricks.yml) e [`resources/`](../resources/) |
| **Duração** | ~120 minutos |
| **Pré-requisito** | Aula 2 feita (bronze no ar); computador com terminal; conta no GitHub |

### Aula 2 × Aula 3: qual a diferença?

| | Aula 2 | Aula 3 |
|---|---|---|
| O que entrega | A ingestão: o dado chega sozinho na bronze | A modelagem: silver, gold e a garantia de que estão certas |
| Ideia | **Eu construo e entendo** | **Eu profissionalizo com IA** |
| Onde o código mora | Notebooks no workspace | Repositório Git |
| Como a transformação roda | Célula por célula | Pipeline declarativo: eu digo *o que* cada tabela é, o Databricks descobre a ordem |
| Como o Job existe | Clicado na interface | Arquivo YAML versionado |
| Como sei que está certo | Olho o resultado | Expectations e testes automáticos param o Job |
| Como vai para produção | Rodo na mão | `databricks bundle deploy` |
| Quem escreve o código | Eu | Eu, com o Claude Code executando e eu revisando |

## Roteiro

| Bloco | Tempo | O que acontece |
|---|---|---|
| Teoria | 15 min | Objetivo de cada camada, pipeline declarativo, qualidade de dados, Claude Code, CLI e MCP |
| Pela interface | 10 min | Criar uma materialized view **clicando**, para entender o conceito |
| Setup | 15 min | Databricks CLI, autenticação, Claude Code, plugin Databricks e MCP |
| Passo 1 | 25 min | Projeto do zero com o Claude Code e os 4 prompts: bronze → silver → gold |
| Passos 2 e 3 | 20 min | Deploy do gabarito, números de referência e placar de qualidade |
| Passo 4 | 10 min | Ver o pipeline falhar de propósito |
| Passo 5 | 20 min | Nova feature a partir do PRD: `gold.vendas_por_regiao` |
| Passo 6 | 5 min | `dev` → `prod` |

---

## Parte 1: base teórica

### O objetivo de cada camada

| Camada | Pergunta que responde | Neste projeto |
|---|---|---|
| **Bronze** | "O que a origem mandou?" | Cópia fiel do data lake e da API do IBGE, com todos os defeitos. Feita na Aula 2. |
| **Silver** | "Posso confiar neste dado?" | Tipos certos (dinheiro em `DECIMAL`), receita calculada, cliente com região, e **cada problema de qualidade marcado e medido**. |
| **Gold** | "Qual a resposta para o negócio?" | Uma tabela por pergunta das diretorias, documentada para o Genie e desenhada para o dashboard da Aula 4. |

### Existe problema de qualidade neste dataset?

Existe, e ele é mais sutil do que "valor vazio". O dado bruto não tem nulos, duplicatas nem números negativos, mas tem:

| Problema | Quanto | O que a silver faz |
|---|---|---|
| Venda de produto que não existe no catálogo | 20 vendas, R$ 4.240,01 | Mantém a venda e marca `produto_cadastrado = false` |
| Venda anterior à criação do produto | 5 vendas, R$ 325,88 | Marca `venda_antes_do_cadastro = true` |
| Preço de concorrente exatamente pela metade do nosso | 55 preços (15 produtos) | Marca `preco_suspeito = true` |
| Marca diferente da citada no nome ("Tênis Nike Air Max", marca Adidas) | 12 produtos | Aparece no placar de qualidade |
| Pronome de tratamento no nome ("Sr.", "Dra.") | 11 clientes | Limpa `nome_cliente` e guarda o original em `nome_original` |

**Por que marcar e não apagar?** Dinheiro que entrou é receita. Se a silver apagasse as 20 vendas sem cadastro, o faturamento cairia R$ 4.240,01 e ninguém saberia por quê. A regra é: o problema fica **visível e medido**, e alguém resolve na origem.

### Lakeflow Declarative Pipelines (antigo Delta Live Tables)

Na Aula 2 você escreveu **como** gravar cada tabela (`df.write.mode("overwrite").saveAsTable(...)`), na ordem certa, célula por célula. Num pipeline declarativo você escreve só **o que** cada tabela é, e o Databricks cuida do resto:

| Você declara | O Databricks faz |
|---|---|
| "`silver.vendas` é esta consulta sobre `bronze.vendas` e `silver.produtos`" | Descobre que precisa calcular `silver.produtos` antes e monta o grafo de dependências |
| "toda venda precisa ter quantidade positiva" (*expectation*) | Confere cada linha, mede quantas passaram e para o pipeline se a regra for crítica |
| Nada sobre infraestrutura | Sobe o compute serverless, grava, otimiza e mostra tudo num grafo visual |

### O que é `CREATE OR REFRESH MATERIALIZED VIEW`?

É o comando que declara uma tabela dentro do pipeline. Por partes:

- **`MATERIALIZED VIEW`**: uma view cujo resultado fica **gravado** como tabela. Quem consulta lê o dado pronto, rápido como uma tabela comum, mas o Databricks sabe qual consulta gera aquele dado e consegue recalculá-lo sozinho, às vezes só com o que mudou (refresh incremental).
- **`CREATE OR REFRESH`**: "se ainda não existe, crie; se já existe, atualize com o dado novo". Rodar dez vezes dá o mesmo resultado que rodar uma: é idempotente, como a ingestão da Aula 2.
- **A lista entre parênteses** declara as colunas com **tipo e comentário**. Se declarar a lista, declare todas as colunas do `SELECT`, com o tipo: sem o tipo, o comentário é ignorado em silêncio.

```sql
CREATE OR REFRESH MATERIALIZED VIEW gold.vendas_temporais (
  data        DATE          COMMENT 'Data da venda.',
  canal_venda STRING        COMMENT 'ecommerce ou loja_fisica.',
  receita     DECIMAL(20,2) COMMENT 'Receita bruta em reais (R$).'   -- comentário de coluna, lido pelo Genie
)
COMMENT 'Vendas agregadas por dia, hora e canal.'   -- comentário da tabela
AS
SELECT data, canal_venda, SUM(receita) AS receita
FROM silver.vendas
GROUP BY data, canal_venda;
```

**Comparando com o que você já conhece:**

| Comando | Onde roda | O que acontece |
|---|---|---|
| `CREATE OR REPLACE TABLE ... AS SELECT` | SQL editor, notebook | Apaga e recria a tabela; comentários adicionados depois se perdem. A ordem das tabelas é sua responsabilidade. |
| `CREATE MATERIALIZED VIEW ... AS SELECT` | SQL editor (warehouse serverless) | Cria uma MV avulsa; você atualiza com `REFRESH MATERIALIZED VIEW nome`. |
| `CREATE OR REFRESH MATERIALIZED VIEW ... AS SELECT` | **Dentro de um pipeline** | O pipeline cria ou atualiza, na ordem certa, com expectations, e os comentários fazem parte da definição. |

> **Por que materialized view e não streaming table?** A ingestão da Aula 2 **sobrescreve** a bronze a cada execução. Uma streaming table só aceita linhas novas e quebraria com a sobrescrita; uma MV relê a fonte e recalcula. Streaming table é para fonte que só cresce (arquivos chegando, Kafka).

### Expectations: a qualidade declarada junto da tabela

```python
@dp.materialized_view()
@dp.expect_all_or_fail({"quantidade_positiva": "quantidade > 0"})   # nunca pode acontecer: para o pipeline
@dp.expect("produto_cadastrado", "produto_cadastrado")               # problema conhecido: só mede
def vendas():
    ...
```

| Tipo | Python / SQL | Quando usar |
|---|---|---|
| **Warn** | `@dp.expect` / `CONSTRAINT ... EXPECT (...)` | Problema conhecido e tolerado: a linha passa e a métrica aparece no pipeline |
| **Drop** | `@dp.expect_or_drop` / `... ON VIOLATION DROP ROW` | Linha inútil que pode ser descartada sem mudar número de negócio |
| **Fail** | `@dp.expect_or_fail` / `... ON VIOLATION FAIL UPDATE` | Regra que nunca pode ser quebrada: melhor parar do que mostrar número errado |

Expectations olham **uma linha por vez**. O que depende de várias linhas ou de várias tabelas (chave única, receita que bate entre silver e gold) fica no notebook de [testes](./testes/03_testes_qualidade.py), que roda depois do pipeline.

### Claude Code, Databricks CLI e MCP: quem faz o quê

| Ferramenta | O que é | Papel na aula |
|---|---|---|
| **Databricks CLI** | O Databricks pelo terminal: `databricks bundle deploy`, `databricks pipelines ...`, consultas SQL | As "mãos" que mexem no workspace |
| **Claude Code** | Agente de IA no terminal que lê o projeto, edita arquivos e roda comandos (inclusive a CLI) | O par de programação |
| **Plugin Databricks** (skills) | Instruções prontas que ensinam o Claude Code a usar a CLI, bundles e pipelines do jeito certo | O "manual" que o agente consulta |
| **MCP** (Model Context Protocol) | Padrão aberto para conectar uma IA a sistemas externos. O Databricks oferece servidores MCP gerenciados (SQL, Genie, funções do Unity Catalog) | Deixa a IA consultar o workspace direto, sem passar pela CLI |

**Skills × MCP:** a skill ensina *como* fazer (qual comando, qual sintaxe). O MCP dá *acesso* a um sistema (rodar SQL, perguntar ao Genie). Na aula usamos os dois: o plugin para construir o projeto e o MCP de SQL para explorar os dados.

### Dados também são software

| Prática | Em dados significa | Neste projeto |
|---|---|---|
| **Versionamento** | Todo código e configuração no Git | Repositório no GitHub |
| **Infraestrutura como código** | Job, pipeline, dashboard e permissões em arquivo, e não em cliques | `databricks.yml` + `resources/*.yml` |
| **Ambientes separados** | Testar sem estragar o que os diretores estão vendo | Targets `dev` e `prod` |
| **Testes** | Provar que o dado está certo antes de alguém usar | Expectations + `testes/03_testes_qualidade.py` |
| **Especificação** | Escrever o que o sistema deve fazer antes de fazer | [`PRD.md`](./PRD.md) |

---

## Parte 2: sua primeira materialized view, pela interface

Antes de automatizar, vale ver o conceito com as próprias mãos.

1. No menu lateral do Databricks, clique em **Jobs & Pipelines → Create → ETL pipeline**.
2. Preencha:
   - **Name:** `minha_primeira_mv`
   - **Default catalog:** `ecommerce`
   - **Default schema:** `silver`
3. Escolha **Start with an empty file** e a linguagem **SQL**. Abre o editor de pipelines, com um arquivo em branco.
4. Cole:

   ```sql
   CREATE OR REFRESH MATERIALIZED VIEW receita_por_canal (
     CONSTRAINT receita_positiva EXPECT (receita > 0) ON VIOLATION FAIL UPDATE
   )
   COMMENT 'Teste da Aula 3: receita por canal a partir da bronze.'
   AS
   SELECT
     canal_venda,
     COUNT(*)                                          AS total_vendas,
     CAST(SUM(quantidade * preco_unitario) AS DECIMAL(12,2)) AS receita
   FROM bronze.vendas
   GROUP BY canal_venda;
   ```

5. Clique em **Run pipeline**. Na primeira vez o serverless leva um ou dois minutos para subir.
6. Observe:
   - o **grafo**, com `receita_por_canal` e a seta vindo de `bronze.vendas`;
   - a aba de **qualidade de dados** da tabela, com a expectation `receita_positiva` e quantas linhas passaram;
   - no **Catalog Explorer**, `ecommerce.silver.receita_por_canal` com o tipo *Materialized view* e o comentário.
7. Rode de novo: a tabela é atualizada, e não duplicada. É o `OR REFRESH`.
8. Troque a condição para `receita > 1000000` e rode: o pipeline **falha** e a tabela continua com o dado anterior. É o `FAIL UPDATE` protegendo o diretor.
9. Limpeza: apague o pipeline (menu ⋮ → **Delete**). A MV criada por ele é apagada junto.

> **E sem pipeline?** No **SQL editor**, com o warehouse serverless, dá para criar uma MV avulsa com `CREATE MATERIALIZED VIEW ... AS SELECT ...` e atualizar com `REFRESH MATERIALIZED VIEW nome`. Serve para uma tabela solta; para uma cadeia silver → gold com qualidade, o pipeline é o lugar certo.

### Isso foi pela interface. Agora: CLI + Claude Code

Tudo o que você fez aqui foi **clicando**: criou o pipeline, escreveu o SQL no editor e apertou **Run**. Funciona para uma tabela, mas o projeto da aula tem 4 silvers, uma gold para cada diretoria, testes, um Job diário e dois ambientes (`dev` e `prod`). Clicando, ninguém sabe o que mudou, não dá para revisar antes de subir e não dá para recriar tudo num workspace novo.

Por isso o resto da aula muda de ferramenta:

| Pela interface (o que você acabou de fazer) | Pela CLI + Claude Code (o resto da aula) |
|---|---|
| Pipeline criado com cliques | Pipeline descrito num YAML (`resources/*.pipeline.yml`) |
| SQL digitado no editor do workspace | Um arquivo `.py` ou `.sql` por tabela, no Git |
| **Run pipeline** | `databricks bundle deploy` e `databricks bundle run` |
| Você escreve cada linha | O Claude Code escreve a partir do PRD e dos prompts; você revisa |
| Um ambiente | `dev` para testar, `prod` para os diretores |

O conceito é o mesmo: `CREATE OR REFRESH MATERIALIZED VIEW`, expectations, grafo. Muda **como** você chega lá. Primeiro o setup.

---

## Parte 3: setup (faça antes da aula se puder)

### 1. Instale a Databricks CLI

Documentação oficial: [docs.databricks.com/aws/en/dev-tools/cli/install](https://docs.databricks.com/aws/en/dev-tools/cli/install).

| Sistema | Comando |
|---|---|
| macOS | `brew tap databricks/tap && brew install databricks` |
| Windows (PowerShell) | `winget install Databricks.DatabricksCLI` |
| Linux | `curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh \| sh` |

Feche e abra o terminal, e confira:

```bash
databricks -v
```

Este projeto foi testado na versão 1.13. Se aparecer algo abaixo de 0.281, atualize (`brew upgrade databricks` ou `winget upgrade Databricks.DatabricksCLI`).

### 2. Autentique no seu workspace

Pegue a URL do seu workspace (o endereço do navegador até `.com`, por exemplo `https://dbc-1234abcd-5678.cloud.databricks.com`).

```bash
databricks auth login --host https://SEU-WORKSPACE.cloud.databricks.com --profile imersao
```

O navegador abre, você faz login e a CLI grava o perfil `imersao` em `~/.databrickscfg`. Confira:

```bash
databricks auth profiles                 # lista os perfis e se estão válidos
databricks current-user me -p imersao    # mostra seu usuário
```

> Todo comando da aula leva `-p imersao`. Sem ele, a CLI procura um perfil padrão e dá `cannot configure default credentials`.

### 3. Instale o Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash      # macOS / Linux
irm https://claude.ai/install.ps1 | iex              # Windows (PowerShell)
```

Confira com `claude --version`. Na primeira vez que rodar `claude`, ele abre o navegador para você entrar com sua conta Claude (plano Pro, Max ou chave de API).

### 4. Instale o plugin Databricks no Claude Code

Dentro do `claude`, digite:

```
/plugin install databricks@claude-plugins-official
```

O plugin traz as skills da Databricks (CLI, bundles, pipelines, jobs, dashboards, Genie). Não é preciso chamá-las pelo nome: quando você pede algo de Databricks, o Claude Code carrega a skill certa sozinho. Rode `/plugin` para ver o que está instalado.

### 5. Conecte o MCP de SQL do Databricks

O servidor MCP gerenciado de SQL deixa o Claude Code rodar consultas no seu workspace. Crie um token (seu avatar → **Settings → Developer → Access tokens → Generate new token**) e rode no terminal:

```bash
claude mcp add --transport http databricks-sql \
  https://SEU-WORKSPACE.cloud.databricks.com/api/2.0/mcp/sql \
  --header "Authorization: Bearer SEU_TOKEN"
```

Dentro do `claude`, `/mcp` mostra se a conexão está ativa. Outros servidores gerenciados seguem o mesmo formato, como o do Genie (`/api/2.0/mcp/genie/{id_do_genie_space}`), que vamos usar na Aula 4. A lista completa está em [Managed MCP servers](https://docs.databricks.com/aws/en/generative-ai/mcp/managed-mcp).

> **Cuidado com o token:** ele dá acesso ao seu workspace. Não cole em arquivo do repositório nem em print. Se vazar, revogue na mesma tela onde criou.
>
> Se o MCP gerenciado não estiver disponível no seu workspace, siga sem ele: o plugin Databricks faz as mesmas consultas pela CLI (`databricks experimental aitools tools query`).

### Alternativa gratuita: Genie Code

O Claude Code é pago. Sem assinatura, dá para acompanhar a aula com o **Genie Code**, o assistente que já vem no Databricks, inclusive na Free Edition: ele gera e explica código dentro do editor de pipelines e dos notebooks. Você perde a execução de comandos no seu computador, mas o fluxo PRD → código → qualidade → deploy é o mesmo.

---

## Parte 4: a aula passo a passo, com CLI e Claude Code

### Passo 1: o projeto do zero, com o Claude Code

Aqui você refaz o que está pronto neste repositório, começando de uma pasta vazia, como faria numa empresa. O repositório serve de **gabarito**.

**2.1. Crie o esqueleto do projeto com a CLI**

```bash
mkdir ecommerce-pipeline && cd ecommerce-pipeline
databricks pipelines init -p imersao
```

Responda às perguntas: nome `ecommerce_pipeline`, catálogo `projetoaovivo`, schema pessoal **no**, linguagem **python**. A CLI cria um bundle (`databricks.yml`), um recurso de pipeline em `resources/` e uma pasta `transformations/` com exemplos.

**2.2. Abra o Claude Code**

```bash
claude
```

**2.3. Os 4 prompts**

O projeto inteiro da Aula 3 sai de quatro prompts, um por arquivo em [`prompts/`](./prompts/) (`prompt_01.md` a `prompt_04.md`):

| # | Prompt | O que sai |
|---|---|---|
| 1 | A silver | Convenções no `CLAUDE.md`, pipeline, 4 tabelas silver com expectations, notebook de testes e o Job |
| 2 | Diretoria de Customer Success | `gold.clientes_segmentacao` |
| 3 | Diretoria Comercial | `gold.vendas_temporais`, `gold.vendas_produtos`, `gold.vendas_detalhadas` |
| 4 | Diretoria de Pricing | `gold.precos_competitividade` |

Os prompts trabalham no catálogo `projetoaovivo`, que já tem as 4 tabelas bronze. Cada prompt traz o contexto, as regras de negócio, as colunas que o dashboard e o Genie da Aula 4 esperam e os números para conferir no fim. Entre um prompt e outro, **revise**: leia os arquivos que ele criou, confira os números e pergunte o porquê do que não entendeu.

Compare o resultado com o gabarito ([`pipeline/`](./pipeline/)). Não precisa ser idêntico, mas os números de referência (Passo 3) precisam bater.

### Passo 2: deploy do gabarito

De volta a este repositório:

```bash
cd Imersao-Jornada-Databricks
databricks bundle validate --strict -t dev -p imersao
databricks bundle deploy -t dev -p imersao
databricks bundle run pipeline_ecommerce -t dev -p imersao
```

O Job tem 3 tarefas:

```
ingestao_bronze  →  transformacao (pipeline: 4 silvers + 6 golds)  →  testes_qualidade
```

Abra o pipeline **[dev seu_usuario] Transformação E-commerce** no workspace e veja o grafo: ninguém escreveu a ordem das tabelas, o pipeline deduziu pelas consultas.

> **Já rodou a versão antiga da Aula 3?** As tabelas `silver.*` e `gold.*` antigas são tabelas comuns, e uma materialized view não assume o lugar de uma tabela que já existe. Apague-as uma vez antes do primeiro run (SQL editor): `DROP TABLE IF EXISTS ecommerce.silver.vendas;` e o mesmo para `produtos`, `clientes`, `preco_competidores`, `gold.vendas_temporais`, `gold.vendas_produtos`, `gold.clientes_segmentacao` e `gold.precos_competitividade`.

### Passo 3: números de referência e placar de qualidade

| O que conferir | Esperado |
|---|---|
| Receita total | R$ 974.077,28 (3.020 vendas) na silver e em `vendas_temporais`, `vendas_produtos`, `clientes_segmentacao` e `vendas_detalhadas` |
| Clientes por região | Norte 17, Nordeste 12, Centro-Oeste 9, Sudeste 8 e Sul 4 |
| `gold.clientes_segmentacao` | 10 VIP, 25 TOP_TIER e 15 REGULAR |
| `gold.precos_competitividade` | 35 produtos mais caros que todos os concorrentes |

E o placar, em `gold.qualidade_dados`:

| Regra | Severidade | Linhas | Receita afetada |
|---|---|---:|---:|
| Venda de produto não cadastrado | ALERTA | 20 | R$ 4.240,01 |
| Venda anterior à criação do produto | ALERTA | 5 | R$ 325,88 |
| Preço de concorrente abaixo de 60% do nosso | ALERTA | 55 | |
| Marca do produto diferente da marca citada no nome | ALERTA | 12 | |
| Produto com nome igual ao de outro produto | INFORMATIVO | 137 | |
| Produto monitorado em menos de 4 concorrentes | INFORMATIVO | 109 | |
| Nome de cliente com pronome de tratamento | CORRIGIDO | 11 | |

No pipeline, clique em `vendas` e abra a aba de qualidade de dados: `produto_cadastrado` mostra 20 linhas com falha (warn), e as regras de `fail` mostram 100% de aprovação.

As mesmas métricas ficam no **event log** do pipeline, que dá para consultar em SQL:

```sql
SELECT
  origin.flow_name  AS tabela,
  e.name            AS regra,
  e.passed_records  AS passou,
  e.failed_records  AS falhou
FROM (
  SELECT origin, timestamp, explode(from_json(
    details:flow_progress:data_quality:expectations,
    'array<struct<name:string, passed_records:bigint, failed_records:bigint>>'
  )) AS e
  FROM event_log(TABLE(ecommerce.silver.vendas))   -- qualquer tabela do pipeline serve
  WHERE event_type = 'flow_progress'
    AND details:flow_progress:data_quality IS NOT NULL
)
QUALIFY ROW_NUMBER() OVER (PARTITION BY tabela, regra ORDER BY timestamp DESC) = 1
ORDER BY tabela, regra;
```

| Tabela | Regra | Falhou |
|---|---|---:|
| `silver.vendas` | `produto_cadastrado` (warn) | 20 |
| `silver.vendas` | `venda_depois_do_cadastro` (warn) | 5 |
| `silver.preco_competidores` | `preco_plausivel` (warn) | 55 |
| todas | regras `fail` | 0 |

Peça ao Claude Code (com o MCP de SQL ou a CLI):

```
Confira no workspace (perfil imersao) os números de referência do CLAUDE.md e me mostre a
tabela gold.qualidade_dados.
```

### Passo 4: veja o pipeline falhar (de propósito)

```
Em pipeline/silver/vendas.py, mova a regra produto_cadastrado de @dp.expect_all para
@dp.expect_all_or_fail. Faça o deploy em dev, rode o Job e me explique o que aconteceu.
```

O pipeline para em `silver.vendas`, nenhuma gold é recalculada, `testes_qualidade` nem roda e você recebe um e-mail. É isso que você quer em produção: **parar antes de mostrar número errado**. Depois, peça para desfazer.

Faça o mesmo com um teste entre tabelas: troque o limite de produtos não cadastrados de 1% para 0,5% em `testes/03_testes_qualidade.py`. O real é 0,66%, então o Job fica vermelho na última tarefa.

### Passo 5: nova feature a partir do PRD

A seção 9 do [`PRD.md`](./PRD.md) descreve `gold.vendas_por_regiao`. Peça:

```
Implemente a próxima feature descrita na seção 9 do PRD.md, seguindo o CLAUDE.md.
Antes de editar, me mostre o plano. Depois do deploy em dev, rode o Job e confira
a reconciliação da receita.
```

Revise o que ele propõe, aprove e acompanhe:
1. o novo arquivo `pipeline/gold/vendas_por_regiao.sql`, com comentários em todas as colunas;
2. o novo teste de reconciliação;
3. `bundle validate`, `deploy` e `run` até ficar verde.

> Esqueceu um comentário de coluna? O teste `gold: toda coluna tem comentário` pega.

### Passo 6: commit e produção

```bash
git add -A && git commit -m "Adiciona gold.vendas_por_regiao"
git push
databricks bundle deploy -t prod -p imersao
databricks bundle summary -t prod -p imersao    # links do Job, do pipeline e do dashboard
```

Em `prod`, o Job fica agendado para todo dia às 6h, e o dashboard **Diretoria E-commerce** lê da gold.

---

## Erros comuns

| Erro | Causa | Como resolver |
|---|---|---|
| `cannot configure default credentials` | Faltou o perfil | Use `-p imersao` em todo comando |
| `Metastore storage root URL does not exist` | Tentou criar catálogo pela API | Crie com SQL (`CREATE CATALOG IF NOT EXISTS ecommerce`) ou rode a Aula 1 |
| Pipeline falha dizendo que a tabela já existe ou não é gerenciada por ele | Tabela antiga criada por notebook com o mesmo nome | `DROP TABLE` na tabela antiga (Passo 2) e rode de novo |
| `CREATE OR REPLACE MATERIALIZED VIEW` rejeitado no pipeline | Sintaxe do SQL editor, não do pipeline | Dentro do pipeline é `CREATE OR REFRESH` |
| Pipeline parado em *Initializing* | Primeira subida do serverless | Espere alguns minutos; não cancele |
| Pipeline vermelho com `EXPECTATION_VIOLATION` | Uma regra `fail` foi quebrada | Abra a tabela no grafo → aba de qualidade: mostra a regra e as linhas |
| `warehouse "Serverless Starter Warehouse" not found` | O warehouse foi renomeado | Ajuste `variables.warehouse_id.lookup` no `databricks.yml` |
| Job vermelho em `testes_qualidade` | Algum teste entre tabelas encontrou problema | A saída da tarefa mostra qual teste falhou e quantas linhas |

## Amanhã

O dado está organizado, com qualidade medida, documentado e atualizado todo dia. Na [Aula 4](../aula-04-genie/) os diretores deixam de depender de você para perguntar: eles conversam com a gold em português, pelo **Genie**, e acompanham tudo no dashboard.
