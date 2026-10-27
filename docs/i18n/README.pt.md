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

Quando o aplicativo confirmar que o ZIP seguro está pronto, anexe **ADBMedic-report.zip** ao seu chat de IA (ChatGPT, Claude ou outro) e peça que siga as instruções incluídas. O arquivo contém medições e um pedido de conclusões claras, passos detalhados e acompanhamento. A opção 2 abre a pasta do ZIP. Se o chat não ler ZIP, extraia e anexe REPORT.md, facts.json e MANUAL-ANALYSIS-PROMPT.md.

A interface de diagnóstico atualmente oferece russo e inglês e escolhe o idioma conforme o idioma de exibição do Windows. Para os demais idiomas, usa o inglês. Não é preciso escolher um modo nem adicionar parâmetros ao comando.

## Já baixou o projeto?

Abra o PowerShell na pasta do projeto e execute:

```powershell
.\bootstrap.ps1
```

## Seus dados

O script lê os dados de diagnóstico e os salva no seu computador em `%LOCALAPPDATA%\ADBMedic`. Ele não altera as configurações do telefone nem envia dados de diagnóstico para a nuvem.

O relatório local é privado. Compartilhe apenas o ZIP preparado: ele contém medições numéricas validadas e rótulos de processos desta sessão, sem identificadores nem registros brutos. Se a validação falhar, nenhum ZIP para compartilhamento será criado. Não há diagnóstico nem envio para IA automáticos; a análise é feita pelo chat escolhido. [Formato de exportação e limites](../SAFE-HANDOFF.md).

Testado com Windows PowerShell 5.1. Uma execução completa com um telefone real ainda precisa ser verificada.

[Guia do desenvolvedor: testes, proteção do Git e opções avançadas](../DEVELOPMENT.md) · [Licença MIT](../../LICENSE)
