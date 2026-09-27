# Pipeline E-commerce: Da Bronze ao Genie em 4 Aulas

> **Pipeline completo de dados** com ingestão automatizada, transformações validadas, dashboards publicados e IA para consultas em linguagem natural. Projeto profissional usando Git, Asset Bundles, Lakeflow Pipelines e Unity Catalog.

[![Databricks](https://img.shields.io/badge/Databricks-Free%20Edition-FF3621?logo=databricks)](https://www.databricks.com)
[![Delta Lake](https://img.shields.io/badge/Delta%20Lake-Lakehouse-00ADD8?logo=delta)](https://delta.io/)
[![Unity Catalog](https://img.shields.io/badge/Unity%20Catalog-Governance-4285F4)](https://www.databricks.com/product/unity-catalog)

## 📋 Sobre o Projeto

Pipeline end-to-end de dados de um **e-commerce brasileiro** com vendas em dois canais (site e loja física). O projeto responde às necessidades de 3 diretorias através de um lakehouse moderno:

* **Diretoria Comercial**: Receita, vendas, ticket médio por canal/produto/período
* **Diretoria de Customer Success**: Segmentação de clientes, análise regional, clientes VIP
* **Diretoria de Pricing**: Competitividade de preços vs. 4 concorrentes

### 🎯 Objetivos Técnicos

* Arquitetura **medalhão** (Bronze → Silver → Gold)
* Ingestão automatizada de data lake (S3/Supabase) + API (IBGE)
* Pipeline declarativo com **Lakeflow Spark Declarative Pipelines** (SDP)
* Qualidade de dados com **expectations** e testes de reconciliação
* Deploy via **Declarative Automation Bundles** (DABs)
* Dashboards AI/BI publicados
* Genie Space para consultas em linguagem natural

### 📊 Resultados

* **5 tabelas gold** prontas para análise
* **Job diário** orquestrado (ingestão → transformação → testes)
* **3 dashboards** publicados (Bronze, Gold 3 páginas, métricas em português)
* **Genie Space** configurado com 10 exemplos SQL e 6 starter questions
* **100% versionado** no Git

---

## 📚 Índice

1. [Estrutura do Projeto](#-estrutura-do-projeto)
2. [Pré-requisitos](#%EF%B8%8F-pré-requisitos)
3. [Jornada das 4 Aulas](#-jornada-das-4-aulas)
4. [Setup Inicial](#-setup-inicial)
5. [Deploy com Asset Bundles](#-deploy-com-asset-bundles)
6. [Validação e Testes](#-validação-e-testes)
7. [Referência de Comandos](#-referência-de-comandos)
8. [Solução de Problemas](#-solução-de-problemas)

---

## 📁 Estrutura do Projeto

```
E-commerce/
├── databricks.yml              # Configuração do Asset Bundle
├── PRD.md                      # Documentação de requisitos do produto
├── CLAUDE.md                   # Instruções para Claude Code
├── README.md                   # Este arquivo
├── pipeline/
│   ├── bronze/                  # Ingestão (Python)
│   │   └── 01_ingestao_bronze_gabarito.py
│   ├── silver/                  # Transformações Silver (PySpark + SDP)
│   │   ├── produtos.py
│   │   ├── clientes.py
│   │   ├── preco_competidores.py
│   │   └── vendas.py
│   └── gold/                    # Tabelas Gold (SQL + SDP)
│       ├── vendas_temporais.sql
│       ├── vendas_produtos.sql
│       ├── clientes_segmentacao.sql
│       ├── precos_competitividade.sql
│       ├── vendas_detalhadas.sql
│       └── qualidade_dados.sql
├── testes/
│   └── 04_testes_qualidade.py   # Testes de reconciliação e validação
├── resources/
│   ├── pipeline_ecommerce.job.yml        # Definição do Job diário
│   ├── diretoria_aula01.dashboard.yml    # Dashboard Bronze
│   ├── diretoria_gold.dashboard.yml      # Dashboard Gold
│   └── genie_instructions.txt            # Configuração do Genie Space
├── dados/                       # Arquivos CSV/Parquet de exemplo
├── dashboards/                  # Exports dos dashboards criados
└── prompts/                     # Prompts para Claude Code (Aula 3)
```

---

## ⚙️ Pré-requisitos

### 1. Conta Databricks

* [Databricks Free Edition](https://www.databricks.com/try-databricks) (sem cartão de crédito)
* Conta **verificada** para acesso externo (data lake S3, API IBGE)
* Serverless compute habilitado

### 2. Ferramentas Locais

#### Databricks CLI (versão >= 0.218)

```bash
# macOS
brew tap databricks/tap && brew install databricks

# Windows (PowerShell)
winget install Databricks.DatabricksCLI

# Linux
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# Verificar instalação
databricks -v
```

#### Git

```bash
git --version
```

### 3. Data Lake (Opcional)

* **Supabase** com Storage configurado (protocolo S3)
* Bucket `Datalake` com arquivos `.parquet`
* Alternativamente, upload manual dos CSVs

---

## 🚀 Jornada das 4 Aulas

### Aula 1: SQL & Dashboard (Bronze Manual)
**Objetivo**: Responder os 3 diretores com SQL e publicar dashboard

**Criamos**: Catálogo + schemas, 4 tabelas bronze (upload manual), 12 consultas SQL, Dashboard Bronze

### Aula 2: Python & Engenharia de Dados (Bronze Automatizada)
**Objetivo**: Automatizar ingestão do data lake

**Criamos**: Notebook Python com S3/boto3, API IBGE, Job agendado 06h

### Aula 3: Claude Code & Lakeflow Pipelines (Silver + Gold)
**Objetivo**: Profissionalizar com pipeline declarativo, testes e Git

**Criamos**: 4 tabelas silver + 6 gold (SDP), expectations, Job orquestrado, testes reconciliação, Dashboard Gold, Asset Bundle, Git

### Aula 4: Genie (IA para Consultas)
**Objetivo**: IA responde perguntas em português

**Criamos**: Genie Space configurado (4 tabelas, 10 exemplos SQL, 6 starter questions)

---

## 🔧 Setup Inicial

### 1. Autenticação no Databricks

```bash
databricks auth login --host https://SEU-WORKSPACE.cloud.databricks.com --profile ecommerce
databricks auth profiles
databricks current-user me -p ecommerce
```

### 2. Clonar o Repositório

```bash
git clone <URL-DO-SEU-REPOSITORIO>
cd E-commerce
```

### 3. Upload dos Dados (Primeira Execução)

**Opção A: Upload manual** (recomendado para primeira vez)
1. Databricks → **+ New → Add or upload data**
2. Arraste CSVs da pasta `dados/` para `ecommerce.bronze.*`

**Opção B: Data Lake S3** (produção)
1. Configure credenciais em `pipeline/bronze/01_ingestao_bronze_gabarito.py`
2. Execute notebook

---

## 📦 Deploy com Asset Bundles

### Validar e Deploy

```bash
# Validar
databricks bundle validate --strict -p ecommerce

# Deploy desenvolvimento
databricks bundle deploy -t dev -p ecommerce

# Deploy produção
databricks bundle deploy -t prod -p ecommerce
```

### Executar Job

```bash
# Listar jobs
databricks jobs list -p ecommerce

# Executar
databricks jobs run-now "Pipeline E-commerce" -p ecommerce

# Monitorar
databricks jobs runs list -p ecommerce
```

---

## ✅ Validação e Testes

### 1. Verificar Tabelas

```sql
USE CATALOG ecommerce;
SHOW TABLES IN bronze;  -- 5 tabelas
SHOW TABLES IN silver;  -- 4 tabelas
SHOW TABLES IN gold;    -- 6 tabelas

SELECT COUNT(*) FROM bronze.vendas;  -- 3020
```

### 2. Validar Pipeline

**Jobs & Pipelines → Pipelines** → Verificar grafo completo e status verde

### 3. Validar Dashboards

**Dashboards** → Verificar 3 dashboards, métricas em BRL, filtros funcionando → **Publish**

### 4. Validar Genie Space

**Genie** → **Diretoria E-commerce** → Testar perguntas:
```
Qual foi a receita total do período?
# Esperado: R$ 974.077,28
```

---

## 📖 Referência de Comandos

### Asset Bundles

```bash
databricks bundle validate --strict -p ecommerce
databricks bundle deploy -t dev -p ecommerce
databricks bundle deploy -t prod -p ecommerce
databricks bundle destroy -t dev -p ecommerce
```

### Jobs

```bash
databricks jobs list -p ecommerce
databricks jobs run-now "Pipeline E-commerce" -p ecommerce
databricks jobs runs list -p ecommerce
```

### Git

```bash
git status
git add .
git commit -m "feat: descrição"
git push origin main
```

---

## 🔍 Solução de Problemas

### "cannot configure default credentials"
```bash
# Sempre usar -p ecommerce
databricks bundle deploy -t dev -p ecommerce
```

### "ConnectionError"
**Causa**: Conta não verificada (Free Edition restringe acesso externo)
**Solução**: Verificar conta via LinkedIn

### Pipeline falha com "Table already exists"
```sql
DROP TABLE IF EXISTS ecommerce.silver.produtos;
```

### Dashboard mostra "No data"
```bash
# Executar job
databricks jobs run-now "Pipeline E-commerce" -p ecommerce
```

### Genie não responde corretamente
Executar notebook `aula-04-genie/01_preparar_dados_para_ia` (aplica comentários nas tabelas)

---

## 📚 Recursos Adicionais

* **Documentação Databricks**: https://docs.databricks.com
* **Asset Bundles**: https://docs.databricks.com/dev-tools/bundles/
* **Lakeflow Pipelines**: https://docs.databricks.com/workflows/delta-live-tables/
* **Genie**: https://docs.databricks.com/genie/
* **Unity Catalog**: https://docs.databricks.com/data-governance/unity-catalog/

---

**Bom pipeline! 🚀**
