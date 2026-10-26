# ADBMedic

**Local-first Android system diagnostics via ADB.**

Repository: [ADBMedic on GitHub](https://github.com/andrewpozdnakov7-jpg/ADBMedic).

Development version. Keep device logs and local sessions private. Original repository history is not included.

## Current status

This is a development source repository with offline privacy checks. It is **not a diagnostic-data sanitizer**. Do not publish real logs or device sessions.

The prior raw-dump ZIP exporter and remote Codex analyzer are **intentionally disabled** until TASK-001 and TASK-002 privacy requirements are met. The ADB read-only collection and local preliminary Markdown/HTML report remain available. Device-specific runtime data must stay on the local computer.

## Install and launch with one PowerShell command

Windows PowerShell 5.1 is supported; PowerShell 7 has not been verified in this environment.

After the project files have been published to the repository's `main` branch, run:

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/Install-ADBMedic.ps1').Content.TrimStart([char]0xFEFF))) -Launch
```

This command downloads and executes the installer from the selected repository. Review its source before running it. The installer asks before downloading application files, resolves the current `main` commit, and downloads an explicit list of required files from that same commit. It validates PowerShell syntax before activating the installation. No Git, npm or administrator rights are required.

The commit is resolved from GitHub's public Git reference advertisement, parsed directly in PowerShell. Installation does not require REST API quota, a token or the Git executable. All reference packets must be valid and identify exactly one `main` revision; otherwise installation fails closed.

Application versions are stored separately under `%LOCALAPPDATA%\ADBMedic\app\<commit>`. Existing versions are not overwritten. Repeating the command installs the current revision; an existing copy of that revision must match the downloaded files. Diagnostics remain in the separate local `%LOCALAPPDATA%\ADBMedic\data` directory. The installer does not read them.

The default launch mode is `offline`: local collection and reports. Raw-dump ZIP export and cloud analysis remain disabled. If ADB is missing, the launcher offers a separate download of official Google Platform-Tools. Collection also requires confirmation.

Add `-Language ru-RU` or `-Language en-US` to select the interface language. Add `-NoBrowser` to suppress opening reports. Add `-SkipInstall` to prevent downloading ADB; it must then already be available. These switches follow `-Launch` on the same command.

Downloads use GitHub's HTTPS endpoints and a single resolved commit; this is not an independent signature or provenance verification. The installer does not update itself or run in the background.

## Local launcher

From the extracted project directory, run:

```powershell
.\bootstrap.ps1 -Mode offline
```

The local bootstrap checks project files without downloading project updates. For read-only ADB capture, a connected and authorized Android device is required. An ADB download is offered only with user confirmation if ADB is missing. **For development tests, do not connect a phone or run ADB.**

To inspect only the synthetic tests:

```powershell
.\smoke-test.ps1
.\tests\Install-ADBMedic.Tests.ps1
.\tests\Runtime-Safety.Tests.ps1
.\scripts\Install-GitHooks.ps1
.\privacy-audit.ps1
```

## Codex developer instructions

1. Read `AGENTS.md` and `docs/00_MANAGER_RULES.md`.
2. Follow the current owner-authorized scope and `docs/01_CODEX_TASK_001.md` for the pending privacy work.
3. Follow `docs/02_ACCEPTANCE_CHECKLIST.md` and produce `docs/IMPLEMENTATION-001.md`.
4. The owner authorizes TASK-001 branches, commits, push and Pull Requests after successful checks. Use local Git identity `Andrew` with `andrewpozdnakov7@gmail.com`. Never force-push existing branches or publish releases. CI is not enabled. Do not read private diagnostic folders.
5. Before every publication, complete the mandatory [privacy check](docs/PUBLICATION-PRIVACY.md) on the exact outgoing files and metadata.

## Threat boundaries

- Source ZIP: source code and synthetic examples only. No previous git history, profile-specific names, private case study, or authentic diagnostic data.
- Local session data: potentially private. Its contents are **never safe for sharing by default**.
- Cloud model access: can disclose selected contents, and is disabled pending a verified sanitizer.
- Automatic ZIP export: disabled until privacy gate is implemented and verified.
- The MIT copyright line preserves the attribution already present in the owner-created repository.
- Changing source text or the project name cannot guarantee anonymity against code-similarity matching to previously public code. Never republish unchanged old history.

## Roadmap

1. TASK-001: offline privacy audit, gate test coverage, remove data/identity paths and prevent unsafe output.
2. TASK-002: safe export schema and redaction, with rejection when unknown data may expose identities.
3. TASK-003: reliable startup, resilient ADB, automated diagnosis as an explicitly opted-in action.
4. Later: iterative guided investigation and before/after evidence tracking.

License: MIT.

## Commit, push and source archive protection

Run `./scripts/Install-GitHooks.ps1` once per checkout. Hooks audit the worktree, staged blobs, commit message/identity and every outgoing ref's reachable history. Run `./privacy-audit.ps1 -Mode Staged` before committing and `./privacy-audit.ps1 -Mode History -Revision HEAD` before pushing. Only files in `source-manifest.json` are permitted. A private file remains blocked if added with Git's force option.

The smoke test includes clean and synthetic-secret privacy tests, real local hooks and safe-archive tests; all use local synthetic Git repositories and mocked diagnostics. No real ADB, device, signing material or external diagnostic data is used.

`./scripts/Build-SafeSourceArchive.ps1` audits a source copy, archives only manifest-listed files, re-extracts and re-audits it. It never enables diagnostic ZIP export. Existing output archives are not overwritten.

Local hooks are not server enforcement and cannot guarantee detection of arbitrary personal names or encoded secrets. Manual review remains mandatory; do not skip checks. PowerShell 7, real-device behavior and an independent security review are not claimed.
