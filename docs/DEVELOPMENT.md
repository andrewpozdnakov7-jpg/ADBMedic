# ADBMedic development

Current architecture: [local handoff v3](SAFE-HANDOFF.md), [portable investigator](../INVESTIGATE.md), [local follow-up](../agent/investigation-rules.md), [check catalog](../agent/check-catalog.json), [CI](CI.md), [publication privacy](PUBLICATION-PRIVACY.md).

Run `powershell.exe -NoProfile -NonInteractive -File scripts/Run-CI.ps1` for offline synthetic suites on Windows PowerShell 5.1. CI also checks PowerShell 7. Tests use no phone, real ADB, downloads or private cases. Source privacy checks run through hooks/CI. User READMEs stay focused on first launch.

Local launch: bootstrap.ps1 without arguments. Followup-ADBMedic.ps1 handles owner-confirmed diagnostic requests. Start-ADBMedic.ps1 -NoBrowser skips the report/folder menu; -CommandTimeoutSeconds controls individual native captures. Legacy Mode/SkipAI arguments do not enable a network AI service.

Private outputs belong in user-local application data. Never commit real diagnostic fixtures. Source packaging uses scripts/Build-SafeSourceArchive.ps1. Releases, MCP, privileged debugging and automatic AI uploads are outside this scope.

Current TASK-003 interaction: normal launch offers Resume for compatible saved cases, or a new baseline. The persistent case menu imports JSON through option 3 (picker/typed path, paste ending END, explicit Downloads lookup), confirms known checks once, and returns with a new ZIP. The optional advanced Followup-ADBMedic.ps1 interface shares the same parser/controller and runner. NoBrowser keeps the existing nonpersistent/headless baseline path; no mandatory GUI is introduced. See [implementation report](IMPLEMENTATION-003.md).
