# ADBMedic

**English** · [Русский](docs/i18n/README.ru.md) · [Español](docs/i18n/README.es.md) · [Português](docs/i18n/README.pt.md) · [Français](docs/i18n/README.fr.md) · [简体中文](docs/i18n/README.zh-CN.md)

Phone draining too fast or getting hot? ADBMedic prepares a report for an AI you trust, so it can help investigate and suggest what to do next.

You need an **Android phone, a Windows computer and a USB cable that transfers data**. Nothing needs to be installed on the phone.

## 1. Prepare your phone

1. Open **Settings → About phone → Build number**. It may be under **Software information**. Tap it **7 times** and enter your phone PIN if asked.
2. Find **Developer options** in Settings and turn on **USB debugging**. Menu names vary; Settings search can help.
3. Unlock your phone and connect it to your own computer by USB.

## 2. Run on your computer

Open Start, type **Windows PowerShell** and open it normally. Administrator rights are not needed.

Copy this command, paste it into PowerShell and press **Enter**:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

- Confirm installation and collection with **y**, then Enter. If it offers to download a required tool, confirm that too.
- Watch the phone: if **Allow USB debugging?** appears, tap **Allow** for your computer.
- Describe the problem, for example: “The battery drops a lot overnight.” Wait for collection to finish.

## 3. Send the result to your AI

1. Choose **2** in PowerShell to open the report folder. Choose **1** if you want to view the report yourself.
2. Attach **ADBMedic-report.zip** to ChatGPT, Claude or another AI you trust.
3. Paste the starter prompt shown in PowerShell. The same text is saved in **START-PROMPT.txt** beside the ZIP.

The AI should explain what the evidence shows, give steps to try, or ask for a specific additional check. Its answer defaults to your Windows language; you can ask for another.

**Phone not found?** Unlock it, check the debugging permission, and try another data cable or USB port. If no ZIP was created, keep the error message; do not zip the whole folder yourself.

The report contains private details about your phone and apps. The script uploads nothing automatically. Share the ZIP only with the AI you choose, not on GitHub. You can turn off USB debugging afterward. The script interface currently uses Russian or English.

Keep this window open. If the AI asks for more measurements, choose **3** here: select its downloaded JSON or paste the JSON and finish with **END** on a separate line. Review and confirm the checks, then attach the **new ZIP to the same AI chat**. If you closed the window, run the same launch command and choose **Resume investigation**; your case is saved. [More help](agent/investigation-rules.md#running-a-follow-up-request-on-windows).

When reliable measurements support it, the AI should show a useful chart with time, units, sources and gaps. If data is missing, it should say so.

<details>
<summary>Already downloaded the project?</summary>

Open PowerShell in the project folder and run:

```powershell
.\bootstrap.ps1
```

</details>

[Technical details and development](docs/DEVELOPMENT.md) · [MIT license](LICENSE)
