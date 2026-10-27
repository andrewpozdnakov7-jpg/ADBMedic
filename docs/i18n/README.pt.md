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

Confirme a instalação e a coleta de dados. Se o ADB não estiver disponível, o aplicativo oferecerá o download. No telefone, autorize a depuração a partir deste computador. O relatório será aberto no navegador ao final da coleta.

A interface de diagnóstico atualmente oferece russo e inglês e escolhe o idioma conforme o idioma de exibição do Windows. Para os demais idiomas, usa o inglês. Não é preciso escolher um modo nem adicionar parâmetros ao comando.

## Já baixou o projeto?

Abra o PowerShell na pasta do projeto e execute:

```powershell
.\bootstrap.ps1
```

## Seus dados

O script lê os dados de diagnóstico e os salva no seu computador em `%LOCALAPPDATA%\ADBMedic`. Ele não altera as configurações do telefone nem envia dados de diagnóstico para a nuvem.

Por enquanto, o relatório resume os dados coletados; o diagnóstico automático ainda não está disponível. O envio de dados para IA e a exportação de diagnósticos em ZIP estão desativados. Os arquivos locais podem conter informações pessoais; não os publique.

Testado com Windows PowerShell 5.1. Uma execução completa com um telefone real ainda precisa ser verificada.

[Guia do desenvolvedor: testes, proteção do Git e opções avançadas](../DEVELOPMENT.md) · [Licença MIT](../../LICENSE)
