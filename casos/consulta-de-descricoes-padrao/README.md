# Consulta de descrições padrão

Autor: Roodney Felix Borges · Registrado em 2026-10-08

Página única (HTML, CSS e JavaScript, sem dependências) para consultar e copiar
as descrições padrão de lançamento de um sistema financeiro (Sofia).

## O problema

O campo Descrição do sistema aceita qualquer texto. Sem uma lista fechada, cada
pessoa escreve de um jeito e os relatórios deixam de agrupar corretamente.

## A decisão

Uma lista única, consultável e copiável, em vez de um documento para ler:

- a busca olha qualquer parte do texto ou do código, sem diferenciar acento nem
  maiúscula;
- o filtro por direção do lançamento (entrada ou saída) existe porque algumas
  descrições valem nas duas, como Comissão e Estorno;
- o clique copia o texto exatamente como está, para a grafia não variar;
- sem descrição que sirva, a pessoa não improvisa nem força a mais parecida:
  pede uma variação, que vale só para aquele lançamento e não entra na lista;
- incluir, corrigir ou remover descrição depende de um responsável.

## Como fica

Cerca de 840 descrições (80 de entrada e 759 de saída), cada uma com seu código.
A lista é a de uso geral de uma empresa de consultoria financeira; ficaram de
fora só as entradas que identificavam cliente ou pessoa.

## Como usar

O arquivo está em `ferramenta/descricoes-padrao.html` e abre direto no
navegador, sem instalar nada. Para outra empresa, troque o vetor `DADOS`
(`c` código, `d` direção, `t` texto) e a linha de contagem do cabeçalho.
