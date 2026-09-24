# 10 perguntas para a demonstração do Genie

Da mais fácil para a mais difícil. Cada resposta foi conferida com o SQL abaixo **e** respondida corretamente pelo Genie space deste projeto em 21/09/2026 (10 de 10). As perguntas de limite (lucro) também foram testadas.

Se o seu Genie responder diferente, compare o SQL que ele gerou (botão **Show code**) com o SQL de referência.

---

### 1. Qual foi a receita total do período?
**Esperado:** R$ 974.077,28

```sql
SELECT SUM(receita) AS receita_total FROM ecommerce.gold.vendas_temporais
```

### 2. Qual canal vende mais: e-commerce ou loja física?
**Esperado:** E-commerce, com 2.155 vendas e R$ 705.486,21 (ticket de R$ 327,37). Loja física: 865 vendas e R$ 268.591,07 (ticket de R$ 310,51).

```sql
SELECT canal_venda, SUM(total_vendas) AS vendas, SUM(receita) AS receita,
       ROUND(SUM(receita) / SUM(total_vendas), 2) AS ticket_medio
FROM ecommerce.gold.vendas_temporais
GROUP BY canal_venda ORDER BY receita DESC
```

### 3. Quais são os 5 produtos que mais faturaram?
**Esperado:** Fone de Ouvido Esportivo (R$ 116.462,65), Camisa Social (R$ 115.794,92), Necessaire (R$ 63.668,43), Persiana Vertical (R$ 42.310,56) e Calça Jeans Skinny (R$ 41.313,34).

```sql
SELECT ranking_receita, nome_produto, categoria, receita
FROM ecommerce.gold.vendas_produtos
WHERE ranking_receita <= 5 ORDER BY ranking_receita
```

### 4. Qual categoria gerou mais receita?
**Esperado:** Moda, com R$ 248.124,15 (depois Áudio com R$ 137.061,47 e Acessórios com R$ 120.909,94).

```sql
SELECT categoria, SUM(receita) AS receita
FROM ecommerce.gold.vendas_produtos
GROUP BY categoria ORDER BY receita DESC LIMIT 3
```

### 5. Quem são os 5 melhores clientes?
**Esperado:** Ana Sophia Pereira (MG, R$ 30.716,63), Melissa Pastor (AC, R$ 30.211,93), Murilo Da Mata (RR, R$ 28.285,82), Dr. Benício Gomes (AL, R$ 27.424,23) e Henrique Da Conceição (DF, R$ 26.687,99).

```sql
SELECT ranking_receita, nome_cliente, estado, receita
FROM ecommerce.gold.clientes_segmentacao
WHERE ranking_receita <= 5 ORDER BY ranking_receita
```

### 6. Quantos clientes VIP temos e quanto eles representam da receita?
**Esperado:** 10 clientes VIP, R$ 262.806,22, ou seja, 27,0% da receita.

```sql
SELECT COUNT(*) FILTER (WHERE segmento_cliente = 'VIP') AS clientes_vip,
       SUM(receita) FILTER (WHERE segmento_cliente = 'VIP') AS receita_vip,
       ROUND(SUM(receita) FILTER (WHERE segmento_cliente = 'VIP') * 100 / SUM(receita), 1) AS pct_receita
FROM ecommerce.gold.clientes_segmentacao
```

### 7. Qual região do Brasil gera mais receita?
**Esperado:** Norte, com R$ 333.078,69 e 17 clientes. Depois Nordeste (R$ 216.163,46), Centro-Oeste, Sudeste e Sul.

```sql
SELECT regiao, COUNT(*) AS clientes, SUM(receita) AS receita
FROM ecommerce.gold.clientes_segmentacao
GROUP BY regiao ORDER BY receita DESC
```

### 8. Qual dia da semana vende mais?
**Esperado:** pela **média por dia**, quarta-feira (R$ 34.753,61), seguida de quinta (R$ 34.211,79). Pelo **total**, sábado (R$ 163.379,56).

As duas respostas diferem porque o período (13/12/2025 a 11/01/2026) tem 5 sábados e 5 domingos, mas só 4 de cada dia útil. O Genie foi instruído a mostrar a média por dia justamente para não cair nessa armadilha. **Bom ponto para discutir com a turma:** sem essa instrução, ele responderia "sábado", o que está certo para o total, mas engana.

```sql
SELECT dia_semana, SUM(receita) AS receita, COUNT(DISTINCT data) AS dias_no_periodo,
       ROUND(SUM(receita) / COUNT(DISTINCT data), 2) AS receita_media_por_dia
FROM ecommerce.gold.vendas_temporais
GROUP BY dia_semana, dia_semana_num ORDER BY receita_media_por_dia DESC
```

### 9. Quantos produtos estão mais caros que todos os concorrentes, e em quais categorias?
**Esperado:** 35 produtos. Tênis concentra 15 deles; depois Casa, Cozinha e Moda com 3 cada.

```sql
SELECT categoria, COUNT(*) AS produtos
FROM ecommerce.gold.precos_competitividade
WHERE classificacao_preco = 'MAIS_CARO_QUE_TODOS'
GROUP BY categoria ORDER BY produtos DESC
```

### 10. Dos 10 produtos que mais faturam, quais estão mais caros que a média do mercado?
**Esperado:** 5 produtos: Camisa Social (+6,95%), Persiana Vertical (+2,30%), Shorts Jeans (+2,30%), Vestido Floral (+0,50%) e Notebook Inspiron 15 (+0,33%).

Esta é a pergunta difícil: exige juntar duas tabelas gold. O Genie acerta porque o space tem um **join spec** entre `vendas_produtos` e `precos_competitividade`.

```sql
SELECT v.ranking_receita, v.nome_produto, p.nosso_preco, p.preco_medio_concorrentes, p.diferenca_pct_vs_media
FROM ecommerce.gold.vendas_produtos v
JOIN ecommerce.gold.precos_competitividade p ON v.id_produto = p.id_produto
WHERE v.ranking_receita <= 10 AND p.diferenca_pct_vs_media > 0
ORDER BY v.ranking_receita
```

---

## Perguntas para mostrar os limites

Boas para discutir com a turma o que a IA **não** deve inventar:

- *"Qual foi o nosso lucro?"* Não há custo nos dados. O Genie foi instruído a dizer que só existe receita.
- *"Quanto vendemos ontem?"* Os dados vão até 11/01/2026. O Genie foi instruído a não usar a data de hoje.
- *"Qual o CPF da Ana Sophia?"* Não existe essa coluna. Uma boa resposta admite que o dado não está disponível.
