# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · [Español](README.es.md) · **Português** · [Français](README.fr.md) · [简体中文](README.zh-CN.md)

Coleta dados de diagnóstico do Android e abre um relatório local. Funciona no Windows sem permissões de administrador.

## Primeiros passos

1. Conecte o telefone por USB e ative a depuração USB nele.
2. Abra uma janela normal do **Windows PowerShell**.
3. Cole este comando:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

Confirme a instalação e a coleta de dados. Se o ADB não estiver disponível, o aplicativo oferecerá o download. No telefone, autorize a depuração a partir deste computador. Ao terminar, escolha **1 — abrir o relatório** ou **2 — abrir a pasta dele**. Nada abre automaticamente; pressione Enter para encerrar.

Quando o ZIP de diagnóstico estiver pronto, anexe **ADBMedic-report.zip** a uma IA de confiança e peça que siga as instruções. A IA investiga causas, explica o consumo por aplicativo real com valores, tipos de eventos e períodos, propõe ações e verifica o resultado. Se faltarem dados, fornece comandos ADB específicos de somente leitura com explicações. [Contrato da IA](../../AI-ANALYST.md). A opção 2 abre a pasta. Sem suporte a ZIP, anexe REPORT.md, facts.json, MANUAL-ANALYSIS-PROMPT.md e os arquivos pertinentes de evidence.

A interface de diagnóstico atualmente oferece russo e inglês e escolhe o idioma conforme o idioma de exibição do Windows. Para os demais idiomas, usa o inglês. Não é preciso escolher um modo nem adicionar parâmetros ao comando.

## Já baixou o projeto?

Abra o PowerShell na pasta do projeto e execute:

```powershell
.\bootstrap.ps1
```

## Seus dados

O script lê os dados de diagnóstico e os salva no seu computador em `%LOCALAPPDATA%\ADBMedic`. Ele não altera as configurações do telefone nem envia dados de diagnóstico para a nuvem.

O ZIP é privado: preserva a queixa, modelo/Android, horários da coleta, nomes reais de processos e pacotes, UID/PID e diagnósticos detalhados. Revise antes de compartilhar com a IA escolhida. Não publique no GitHub. Padrões conhecidos de credenciais e chaves privadas bloqueiam o empacotamento; não há garantia de detectar todos os segredos. Nenhum envio ou conselho é executado automaticamente. [Formato e limites](../SAFE-HANDOFF.md).

Testado com Windows PowerShell 5.1. Uma execução completa com um telefone real ainda precisa ser verificada.

[Guia do desenvolvedor: testes, proteção do Git e opções avançadas](../DEVELOPMENT.md) · [Licença MIT](../../LICENSE)
