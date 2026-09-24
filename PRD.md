# PRD: Pipeline de dados do e-commerce

Documento de requisitos do pipeline da Imersão Jornada de Dados. É a fonte da verdade para quem desenvolve, humano ou IA: antes de mudar o código, mude o PRD.

## 1. Contexto

E-commerce brasileiro com vendas em dois canais (site e loja física). Três diretorias precisam de números confiáveis todo dia às 8h:

| Diretoria | Pergunta principal | Tabela gold |
|---|---|---|
| Comercial | Quanto vendemos, quando, em qual canal e com quais produtos? | `gold.vendas_temporais`, `gold.vendas_produtos` |
| Customer Success | Quem são os melhores clientes e onde estão? | `gold.clientes_segmentacao` |
| Pricing | Estamos mais caros que a concorrência? | `gold.precos_competitividade` |
| Todas | Perguntas que cruzam diretorias; posso confiar nos números? | `gold.vendas_detalhadas`, `gold.qualidade_dados` |

## 2. Plataforma

- Databricks Free Edition, compute **serverless**.
- Unity Catalog, catálogo `ecommerce`, schemas `bronze`, `silver` e `gold`.
- Tudo implantado por **Declarative Automation Bundle** (`databricks.yml` na raiz).

## 3. Fontes

| Fonte | Formato | Endereço | Conteúdo |
|---|---|---|---|
| Data lake (Storage do Supabase, protocolo S3) | Parquet | bucket `Datalake`, arquivos `{tabela}.parquet` | `vendas`, `produtos`, `clientes`, `preco_competidores` |
| API do IBGE | JSON | `https://servicodados.ibge.gov.br/api/v1/localidades/estados` | 27 UFs com nome e região |

## 4. Camadas

### Bronze (`aula-02-python-engenharia/01_ingestao_bronze_gabarito.py`, Python) — Aula 2
- Baixa cada Parquet do bucket S3 com `boto3`, lê com pandas e grava uma tabela Delta por arquivo, **sobrescrevendo**.
- Enriquece com a API do IBGE (`bronze.estados_ibge`).
- Cria catálogo e schema se não existirem (**idempotente**).
- Cria também os schemas `silver` e `gold`, que o pipeline da Aula 3 preenche.
- Credenciais no próprio notebook durante a aula; o ideal em produção é movê-las para um secret scope.

### Silver e gold: Lakeflow Declarative Pipeline — Aula 3

Pipeline `Transformação E-commerce` (`resources/transformacao.pipeline.yml`), serverless, catálogo `${var.catalogo}`, schema padrão `silver`. Um arquivo por tabela em `aula-03-claude-code/pipeline/`. Todas as tabelas são **materialized views** com leitura batch (a bronze é sobrescrita a cada execução, o que quebraria uma streaming table).

### Silver (`pipeline/silver/*.py`, PySpark, `@dp.materialized_view`)

| Tabela | Chave | Regras | Expectations |
|---|---|---|---|
| `silver.produtos` | `id_produto` | Remove duplicatas; `preco_atual` em `DECIMAL(10,2)`; `faixa_preco` = PREMIUM (> 1.000), MEDIO (> 500) ou BASICO | fail: chave preenchida, preço > 0 |
| `silver.clientes` | `id_cliente` | Remove duplicatas; `nome_cliente` sem pronome de tratamento (Sr., Sra., Srta., Dr., Dra.) e em formato título, original em `nome_original`; UF em maiúsculas; junta `nome_estado` e `regiao` do IBGE | fail: chave preenchida, cliente com região |
| `silver.preco_competidores` | `id_produto` + `nome_concorrente` | Remove duplicatas; preço em `DECIMAL(10,2)`; `data_coleta` em `timestamp`; `preco_suspeito` = preço abaixo de 60% do nosso | fail: chave preenchida, preço > 0. warn: `preco_plausivel` |
| `silver.vendas` | `id_venda` | Remove duplicatas; `receita = quantidade × preco_unitario`; `data`, `hora`, `dia_semana` (português) e `dia_semana_num` (1 = domingo); `produto_cadastrado` = false quando o produto não existe no catálogo; `venda_antes_do_cadastro` = true quando a venda é anterior à criação do produto. **Nenhuma venda é descartada.** | fail: campos obrigatórios, quantidade e preço > 0, canal em (`ecommerce`, `loja_fisica`). warn: `produto_cadastrado`, `venda_depois_do_cadastro` |

Problemas conhecidos são **marcados em colunas e medidos** (expectation warn), nunca apagados: apagar mudaria a receita.

### Gold (`pipeline/gold/*.sql`, SQL, `CREATE OR REFRESH MATERIALIZED VIEW`)

Comentário na tabela e em **todas** as colunas, dentro da definição: o Genie (Aula 4) lê esses comentários, e por estarem na definição sobrevivem a cada refresh.

| Tabela | Grão | Colunas principais | Consumo |
|---|---|---|---|
| `gold.vendas_temporais` | data × hora × canal | `total_vendas`, `itens_vendidos`, `receita`, `clientes_unicos` | Dashboard (Vendas), Genie |
| `gold.vendas_produtos` | produto | `receita`, `itens_vendidos`, `ticket_medio`, `ranking_receita`, `ranking_na_categoria`. Vendas sem cadastro aparecem como "Produto não cadastrado". | Dashboard (Top 10), Genie |
| `gold.clientes_segmentacao` | cliente (inclusive quem nunca comprou) | `receita`, `total_compras`, `ticket_medio`, `regiao`, `segmento_cliente`, `ranking_receita` | Dashboard (Clientes), Genie |
| `gold.precos_competitividade` | produto com preço de concorrente | `nosso_preco`, média, mínimo e máximo dos concorrentes, `diferenca_pct_vs_media`, `classificacao_preco`, `possui_preco_suspeito`, `receita` | Dashboard (Pricing), Genie |
| `gold.vendas_detalhadas` | venda | Calendário, canal, produto, categoria, marca, cliente, UF, região, segmento, receita e as marcações de qualidade | Filtros cruzados do dashboard, perguntas do Genie que cruzam diretorias |
| `gold.qualidade_dados` | regra de qualidade | `regra`, `tabela`, `severidade` (ALERTA, INFORMATIVO, CORRIGIDO), `linhas_afetadas`, `receita_afetada` | Página de qualidade do dashboard, Genie |

**Regras de negócio**
- Segmentação: VIP a partir de R$ 22.000; TOP_TIER de R$ 17.000 até R$ 21.999,99; REGULAR abaixo disso.
- Classificação de preço: MAIS_CARO_QUE_TODOS, MAIS_BARATO_QUE_TODOS, ACIMA_DA_MEDIA, ABAIXO_DA_MEDIA ou NA_MEDIA.
- `diferenca_pct_vs_media` em pontos percentuais (10 = 10% mais caro).
- Preço suspeito: concorrente abaixo de 60% do nosso preço. O produto continua em todas as contas; a coluna só alerta.

## 5. Qualidade de dados

Duas camadas, cada uma no lugar certo:

**Expectations no pipeline** (regras linha a linha, seção 4). `fail` para o pipeline antes de a gold ser recalculada; `warn` mede o problema no event log.

**Testes entre tabelas** (`aula-03-claude-code/testes/04_testes_qualidade`), depois do pipeline. O Job **falha** se qualquer um encontrar problema:

- unicidade das chaves da silver, de `precos_competitividade`, `vendas_detalhadas` e `qualidade_dados`;
- segmento em (`VIP`, `TOP_TIER`, `REGULAR`); severidade em (`ALERTA`, `INFORMATIVO`, `CORRIGIDO`);
- `receita = quantidade × preco_unitario`; VIP com receita ≥ 22.000; toda venda detalhada com segmento e região;
- **reconciliação:** a receita da silver é igual à de `vendas_temporais`, `vendas_produtos`, `clientes_segmentacao` e `vendas_detalhadas`, e `vendas_detalhadas` tem o mesmo número de vendas da silver;
- vendas de produtos não cadastrados abaixo de **1%** do total;
- toda coluna do schema `gold` tem comentário.

## 6. Orquestração

Job `Pipeline E-commerce` (`resources/pipeline_ecommerce.job.yml`), serverless, todo dia às 06:00 (America/Sao_Paulo), e-mail em caso de falha:

```
ingestao_bronze → transformacao (pipeline: silver + gold) → testes_qualidade
```

Parâmetro do Job: `catalogo` (padrão `ecommerce`). O pipeline usa a mesma variável do bundle.

## 7. Consumo

- Dashboard **Diretoria E-commerce** sobre a gold (`resources/diretoria_gold.dashboard.yml`).
- Genie space **Diretoria E-commerce** (Aula 4) sobre as tabelas gold.

## 8. Requisitos não funcionais

- Nomes de tabelas e colunas em português, `snake_case`, sem acento.
- Nenhum catálogo fixo no código: notebooks usam o widget `catalogo`; o pipeline usa o catálogo da sua configuração (nomes só com `schema.tabela`).
- Notebooks no formato *source* do Databricks (`.py` e `.sql`), com células de texto explicando o porquê. Arquivos do pipeline explicam o porquê em comentários no topo.
- Toda nova tabela gold precisa de comentário em todas as colunas e de pelo menos um teste de reconciliação ou de chave.
- `databricks bundle validate --strict` sem avisos antes de qualquer deploy.

## 9. Próxima feature (exercício da Aula 3)

**`gold.vendas_por_regiao`**: receita, vendas, clientes e ticket médio por região e canal, para a Diretora de Customer Success planejar a equipe regional.

Critérios de aceite:
1. Uma linha por `regiao` × `canal_venda`.
2. A soma da receita bate com `silver.vendas` (novo teste de reconciliação).
3. Novo arquivo `pipeline/gold/vendas_por_regiao.sql`, com comentário na tabela e em todas as colunas.
4. Tabela incluída no Genie space e no dashboard gold (página Clientes).
5. Deploy em `dev`, Job verde, depois deploy em `prod`.
