# ADBMedic development

Current architecture: [local handoff v3](SAFE-HANDOFF.md), [portable investigator](../INVESTIGATE.md), [local follow-up](../agent/investigation-rules.md), [check catalog](../agent/check-catalog.json), [CI](CI.md), [publication privacy](PUBLICATION-PRIVACY.md).

Run `powershell.exe -NoProfile -NonInteractive -File scripts/Run-CI.ps1` for offline synthetic suites on Windows PowerShell 5.1. CI also checks PowerShell 7. Tests use no phone, real ADB, downloads or private cases. Source privacy checks run through hooks/CI. User READMEs stay focused on first launch.

Local launch: bootstrap.ps1 without arguments. Followup-ADBMedic.ps1 handles owner-confirmed diagnostic requests. Start-ADBMedic.ps1 -NoBrowser skips the report/folder menu; -CommandTimeoutSeconds controls individual native captures. Legacy Mode/SkipAI arguments do not enable a network AI service.

Private outputs belong in user-local application data. Never commit real diagnostic fixtures. Source packaging uses scripts/Build-SafeSourceArchive.ps1. Releases, MCP, privileged debugging and automatic AI uploads are outside this scope.