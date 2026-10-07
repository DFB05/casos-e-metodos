# Versionador de telas

Autor: Roodney Felix Borges · Registrado em 2026-10-07

Script em PowerShell, com dois lançadores `.bat`, que guarda versões numeradas
de telas de trabalho (imagens e PDFs) sem apagar o histórico.

## O problema

O arquivo de trabalho de uma tela é sobrescrito a cada ajuste. Sem rotina, as
versões anteriores se perdem ou ficam guardadas à mão, com nomes que não
seguem padrão e que não dizem qual veio antes.

## A decisão

Cada tela ganha uma pasta de arquivo com o mesmo nome dela. O script copia o
arquivo de trabalho para essa pasta como a próxima versão numerada, e o nome
das versões é sempre derivado do nome da pasta. Consequências desenhadas:

- renomear a pasta e rodar de novo renomeia todas as versões já guardadas;
- arquivo de trabalho idêntico à última versão (comparação por SHA-256) não
  gera cópia nova, então rodar duas vezes não custa nada;
- o original fica no lugar; só a cópia vai para a pasta de arquivo;
- antes de mexer em qualquer coisa, o script mostra o plano (cópias e
  renomeações) e pede confirmação;
- se dois arquivos fossem terminar com o mesmo nome, ele aborta sem alterar
  nada;
- as renomeações passam por um nome temporário, para que a troca de nomes
  não sobrescreva versões existentes.

## Como fica a pasta

```
container/
    tela-a.png              arquivo de trabalho, sobrescrito ao longo do dia
    tela-b.png
    tela-a/                 pasta de arquivo, com o nome da tela
        tela-a-1.png
        tela-a-2.png
    tela-b/
        tela-b-1.png
```

Formatos tratados: `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.svg` e `.pdf`.
Outros arquivos são ignorados. Um sufixo opcional (por exemplo `rascunho`)
entra no nome das versões: `tela-a-rascunho-1.png`.

## Como usar

Os arquivos ficam em `ferramenta/`. O `folder-snapshot.ps1` é colocado uma
pasta acima da pasta que contém as telas (o "container"):

| Lançador | Onde fica | O que faz |
|---|---|---|
| `_snapshot.bat` | Dentro da pasta de arquivo de uma tela | Versiona só aquela tela |
| `_snapshot-all.bat` | Dentro do container | Versiona todas as telas de uma vez |

Duplo clique no lançador; o script pergunta o sufixo (pode ficar vazio),
mostra o plano e pede `Y` ou `N`.

## Nota de nome

Nasceu como "versionador de protótipos", quando o trabalho era um protótipo
único. Passou a se chamar versionador de telas porque hoje cada cliente tem as
próprias telas.
