# ADBMedic

**English** · [Русский](docs/i18n/README.ru.md) · [Español](docs/i18n/README.es.md) · [Português](docs/i18n/README.pt.md) · [Français](docs/i18n/README.fr.md) · [简体中文](docs/i18n/README.zh-CN.md)

Collect Android diagnostics and view a local report. Runs on Windows without administrator rights.

## Get started

1. Connect your phone by USB and enable USB debugging on it.
2. Open a regular **Windows PowerShell** window.
3. Paste this command:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

Confirm installation and data collection. If ADB is missing, the app will offer to download it. Allow debugging from this computer on your phone. After collection, choose **1 — open the report** or **2 — open its folder**. Nothing opens automatically; press Enter to finish.

When the app confirms the safe ZIP is ready, attach **ADBMedic-report.zip** to your AI chat (ChatGPT, Claude or another) and ask it to follow the included instructions. The ZIP contains measurements and a request for clear conclusions, detailed steps and feedback. Choose 2 to find it. If your chat cannot read ZIP files, extract it and attach REPORT.md, facts.json and MANUAL-ANALYSIS-PROMPT.md.

The diagnostic interface currently supports Russian and English, selected automatically from your Windows display language. Other languages use English. No mode selection or command options are needed.

## Already downloaded the project?

Open PowerShell in the project folder and run:

```powershell
.\bootstrap.ps1
```

## Your data

The script reads diagnostics and saves them on your computer under `%LOCALAPPDATA%\ADBMedic`. It does not change your phone settings or upload diagnostic data to the cloud.

The local report is private. Share only the prepared ZIP: it contains validated numeric measurements and session-only process labels, with identities and raw logs excluded. If validation fails, no shareable ZIP is created. Automated diagnosis and automatic AI uploads are not performed; your chosen chat provides the analysis. [Export format and limitations](docs/SAFE-HANDOFF.md).

Tested with Windows PowerShell 5.1. A full run with a real phone still needs verification.

[Developer guide: tests, Git protection and advanced options](docs/DEVELOPMENT.md) · [MIT license](LICENSE)
