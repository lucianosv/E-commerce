# Prompt 2: gold da Diretoria de Customer Success

Agora a primeira gold, da Diretoria de Customer Success, no catálogo projetoaovivo. A diretora quer
saber quem são os melhores clientes, onde estão (estado e região) e como dividir a carteira em
segmentos. Ela vai usar um dashboard e o Genie (IA que escreve SQL a partir de perguntas em
português), então a tabela precisa ser autoexplicativa.

REGRAS PARA TODA GOLD (grave no CLAUDE.md, valem para as próximas diretorias)
- SQL, um arquivo por tabela em transformations/gold/, CREATE OR REFRESH MATERIALIZED VIEW gold.<tabela>.
- Declare TODAS as colunas entre parênteses com tipo e COMMENT (sem o tipo, o comentário é ignorado),
  e COMMENT na tabela dizendo quando usar a tabela. Comentários em português, com unidade (R$),
  regra de cálculo e avisos que evitem erro do Genie.
- Inclua TODAS as vendas, inclusive de produto não cadastrado: dinheiro que entrou é receita.
- Período dos dados: 13/12/2025 a 11/01/2026.
- Toda gold nova ganha testes no notebook testes/testes_qualidade.py.

TABELA
gold.clientes_segmentacao, uma linha por cliente, INCLUSIVE quem nunca comprou (LEFT JOIN a partir de
silver.clientes, receita zero). É justamente esse cliente que o time de CS precisa ativar.
Colunas: id_cliente, nome_cliente (sem pronome de tratamento), estado, nome_estado, regiao,
total_compras, receita (COALESCE 0), ticket_medio (ROUND(AVG(receita), 2)), primeira_compra,
ultima_compra, segmento_cliente, ranking_receita (ROW_NUMBER por receita desc).

REGRA DE SEGMENTAÇÃO (definida com a diretora, a partir da distribuição real)
- VIP: receita a partir de R$ 22.000
- TOP_TIER: de R$ 17.000 até R$ 21.999,99
- REGULAR: abaixo de R$ 17.000
Explique no comentário do arquivo por que os limites antigos (R$ 10.000 e R$ 5.000) não serviam:
com eles quase todo mundo virava VIP.

TESTES
- receita total igual à de silver.vendas;
- id_cliente único; segmento só VIP, TOP_TIER ou REGULAR; nenhum VIP com receita abaixo de 22.000;
- toda coluna do schema gold com comentário (ignorando tabelas que começam com __materialization,
  que são internas do pipeline).

NO FIM
Valide, faça o deploy em dev, rode o Job e confira: 50 clientes; 10 VIP, 25 TOP_TIER e 15 REGULAR;
receita R$ 974.077,28; o maior cliente é Ana Sophia Pereira (MG, R$ 30.716,63).
