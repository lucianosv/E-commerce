# Aula 3 em 4 prompts

Com estes quatro prompts, o Claude Code reconstrói num projeto novo toda a modelagem da Aula 3: a silver com qualidade e as golds de cada diretoria. O resultado é o mesmo pipeline que está em [`pipeline/`](../pipeline/), que serve de gabarito.

| # | Prompt | O que sai |
|---|---|---|
| 1 | [A silver](./prompt_01.md) | Convenções no `CLAUDE.md`, pipeline, 4 tabelas silver com expectations, notebook de testes e o Job |
| 2 | [Diretoria de Customer Success](./prompt_02.md) | `gold.clientes_segmentacao` |
| 3 | [Diretoria Comercial](./prompt_03.md) | `gold.vendas_temporais`, `gold.vendas_produtos` e `gold.vendas_detalhadas` |
| 4 | [Diretoria de Pricing](./prompt_04.md) | `gold.precos_competitividade` |

Tudo acontece no catálogo **`projetoaovivo`**, que já tem as 4 tabelas bronze (`vendas`, `produtos`, `clientes` e `preco_competidores`). Os prompts rodam na ordem: a gold Comercial usa o segmento do cliente, que nasce na gold de Customer Success.

## Antes dos prompts

Você precisa de:
- a bronze no catálogo `projetoaovivo` (`projetoaovivo.bronze.vendas`, `produtos`, `clientes` e `preco_competidores`);
- a Databricks CLI autenticada com o perfil `imersao`;
- o Claude Code com o plugin Databricks (setup no [README](../README.md#parte-3-setup-faça-antes-da-aula-se-puder)).

Crie o projeto e abra o Claude Code:

```bash
mkdir ecommerce-pipeline && cd ecommerce-pipeline
databricks pipelines init -p imersao     # nome ecommerce_pipeline, catálogo projetoaovivo, schema pessoal: no, linguagem: python
claude
```

## Como usar

Copie a pasta `prompts/` para dentro do projeto novo e, no Claude Code, rode um de cada vez:

```text
Execute o que está em @prompts/prompt_01.md
```

O `@` anexa o arquivo à conversa. Se preferir, abra o arquivo e cole o texto direto no Claude Code.

Depois de cada prompt, **revise o que ele fez**: leia os arquivos, confira os números que ele mostrar e só então passe para o próximo. Os prompts 2 a 4 leem as regras que os prompts 1 e 2 gravaram no `CLAUDE.md`, então funcionam mesmo numa conversa nova (`/clear`).

## Como saber se deu certo

| Conferência | Esperado |
|---|---|
| Receita em silver e nas 4 golds de vendas e clientes | R$ 974.077,28 (3.020 vendas) |
| Segmentos | 10 VIP, 25 TOP_TIER, 15 REGULAR |
| Pricing | 35 produtos mais caros que todos |
| Qualidade na silver (expectations) | 20 vendas sem cadastro, 5 antes do cadastro, 55 preços suspeitos |
| Comentários | Nenhuma coluna gold sem comentário |
| Job | Verde, com o notebook de testes passando |

Se algum número não bater, não conserte você: descreva a diferença para o Claude Code e peça para ele investigar. Revisar e questionar é o seu papel.
