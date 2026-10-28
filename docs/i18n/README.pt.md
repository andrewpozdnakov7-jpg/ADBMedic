# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · [Español](README.es.md) · **Português** · [Français](README.fr.md) · [简体中文](README.zh-CN.md)

O telefone descarrega rápido ou esquenta? O ADBMedic prepara um relatório para uma IA de confiança, que pode ajudar a investigar e indicar o que fazer.

Você precisa de **um telefone Android, um computador com Windows e um cabo USB que transfira dados**. Não é necessário instalar aplicativo no telefone.

## 1. Prepare o telefone

1. Abra **Configurações → Sobre o telefone → Número da versão**. Pode estar em **Informações do software** ou aparecer como **Número da compilação**. Toque **7 vezes** e informe o PIN do telefone se solicitado.
2. Encontre **Opções do desenvolvedor** e ative **Depuração USB**. Os nomes variam; use a busca das Configurações se necessário.
3. Desbloqueie o telefone e conecte-o por USB ao seu próprio computador.

## 2. Execute no computador

Abra Iniciar, digite **Windows PowerShell** e abra normalmente. Não precisa de permissões de administrador.

Copie o comando, cole no PowerShell e pressione **Enter**:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

- Confirme a instalação e a coleta com **y**, depois Enter. Se oferecer o download de uma ferramenta necessária, confirme também.
- Olhe o telefone: se aparecer **Permitir depuração USB?**, toque em **Permitir** para o seu computador.
- Descreva o problema, por exemplo: “A bateria cai muito durante a noite”. Aguarde a conclusão.

## 3. Envie o resultado à sua IA

1. Escolha **2** no PowerShell para abrir a pasta do relatório. A opção **1** mostra o relatório.
2. Anexe **ADBMedic-report.zip** ao ChatGPT, Claude ou outra IA de confiança.
3. Cole a mensagem inicial exibida no PowerShell. O mesmo texto está em **START-PROMPT.txt**, ao lado do ZIP.

A IA deve explicar as observações, sugerir passos ou pedir uma verificação adicional específica. A resposta usa por padrão o idioma do Windows; você pode pedir outro.

**Telefone não encontrado?** Desbloqueie-o, confira a autorização de depuração e tente outro cabo de dados ou porta USB. Se o ZIP não foi criado, guarde a mensagem de erro; não compacte a pasta inteira por conta própria.

O relatório contém informações privadas do telefone e dos aplicativos. O script não envia nada automaticamente. Compartilhe o ZIP apenas com a IA escolhida, não no GitHub. Depois você pode desativar a depuração USB. A interface do script está em russo ou inglês.

Mantenha esta janela aberta. Se a IA pedir mais medições, escolha **3** aqui: selecione o JSON baixado ou cole o JSON e termine com **END** em uma linha separada. Confira e confirme as verificações; envie o **novo ZIP ao mesmo chat de IA**. Se fechou a janela, execute o mesmo comando e escolha **Retomar investigação**; o caso está salvo. [Mais ajuda](../../agent/investigation-rules.md#running-a-follow-up-request-on-windows).

Quando houver medições confiáveis, a IA deve mostrar um gráfico útil com tempo, unidades, fontes e lacunas. Se faltarem dados, deve explicar isso.

<details>
<summary>Já baixou o projeto?</summary>

Abra PowerShell na pasta do projeto e execute:

```powershell
.\bootstrap.ps1
```

</details>

[Detalhes técnicos e desenvolvimento](../DEVELOPMENT.md) · [Licença MIT](../../LICENSE)
