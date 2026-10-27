# ADBMedic

**English** · [Русский](docs/i18n/README.ru.md) · [Español](docs/i18n/README.es.md) · [Português](docs/i18n/README.pt.md) · [Français](docs/i18n/README.fr.md) · [简体中文](docs/i18n/README.zh-CN.md)

Collect Android evidence for a diagnostic conclusion and treatment plan from an AI you trust. Runs on Windows without administrator rights.

## Get started

1. Connect your phone by USB and enable USB debugging on it.
2. Open a regular **Windows PowerShell** window.
3. Paste this command:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

Confirm installation and data collection. If ADB is missing, the app will offer to download it. Allow debugging from this computer on your phone. After collection, choose **1 — open the report** or **2 — open its folder**. Nothing opens automatically; press Enter to finish.

When the app confirms the diagnostic ZIP is ready, attach **ADBMedic-report.zip** to your trusted AI chat (ChatGPT, Claude or another) and ask it to follow the included instructions. Choose 2 to find it. If your chat cannot read ZIP files, extract it and attach REPORT.md, facts.json, MANUAL-ANALYSIS-PROMPT.md and the relevant files from evidence.

The AI acts as an Android diagnostic specialist: it explains likely causes, energy use and background events by real application/package, cites measurements and their periods, and gives prioritized steps with an outcome check. When evidence is insufficient, it provides focused read-only ADB commands and explains how to return the results. Counts are reported only when actually measured; alarms, wakeups, jobs and other calls are different events. [Full AI role and answer requirements](AI-ANALYST.md).

The archive now includes **SUMMARY.md** and structured battery evidence in **facts.json.analysis**. These retain statistics windows, UID/package mappings, energy estimates, typed counters and source line references. Missing/unsupported data and inconsistencies are explicit. Complete raw files remain in evidence for targeted verification; preprocessing does not declare a diagnosis.

The diagnostic interface currently supports Russian and English, selected automatically from your Windows display language. Other languages use English. No mode selection or command options are needed.

## Already downloaded the project?

Copy the starter prompt printed after collection into the chat together with the ZIP. It is also in the report and **START-PROMPT.txt** beside the ZIP and inside it. The AI answer defaults to your Windows display language; an explicit request for another language in the chat takes priority.

Open PowerShell in the project folder and run:

```powershell
.\bootstrap.ps1
```

## Your data

The script reads diagnostics and saves them on your computer under `%LOCALAPPDATA%\ADBMedic`. It does not change your phone settings or upload diagnostic data to the cloud.

The prepared ZIP is private diagnostic evidence: it retains your complaint, model/Android context, collection times, real package/process names and UID/PID, and detailed selected dumps. Review it and decide whether to share it with your chosen AI. Do not publish it on GitHub. Known credential/private-key patterns block packaging; this is not a guarantee that every secret is detected. Your chosen chat provides the analysis; ADBMedic does not automatically execute its advice. [Export format and limitations](docs/SAFE-HANDOFF.md).

Tested with Windows PowerShell 5.1. A full run with a real phone still needs verification.

[Developer guide: tests, Git protection and advanced options](docs/DEVELOPMENT.md) · [MIT license](LICENSE)
