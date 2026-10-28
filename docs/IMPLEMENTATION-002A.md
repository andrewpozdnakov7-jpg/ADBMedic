# IMPLEMENTATION-002A — Universal evidence and local investigation loop

## Accepted scope

The owner explicitly approved all six implementation points, expanding TASK-002A to include the scoped TASK-002B local follow-up importer/runner. No MCP/automatic AI bridge, privileged debugger attachment, automatic upload or Release is included. Delivery stops at a reviewable PR; main is not merged automatically.

Branch: `task-002-investigation`. Baseline: the current accepted main checkout. PR and reviewed source commit are recorded below after branch publication.

## Implementation

- ADBMedic-Evidence.ps1: fixed comprehensive technical baseline and native stdout/stderr byte transport with separate files, bounded process execution and partial/error metadata. No fixed diagnostic byte cap. Processes are started without a shell; only local capture clients are ended on timeout.
- ADBMedic-Case.ps1 / ADBMedic-Handoff.ps1: stable random case ID, streaming exact-byte copy, SHA-256 and ZIP re-read validation; original raw evidence and complaint preserved including BOM/binary/invalid text. Derived reports remain separate. Private ZIPs are not screened through source privacy regex or known-secret filters.
- manifest.json, device.json, conditions.json and facts.json v3 describe command outcomes, provenance, units/windows, measured/cumulative/estimated kinds, uncertainties and collection conditions. Known failures do not become parsed facts. Unsupported formats and derived parser limits do not truncate raw files.
- INVESTIGATE.md / agent/: vendor-neutral, case-language investigation, differential hypotheses, source citations/confidence, reversible actions when justified, 1–3 discriminating follow-up checks, and reconciliation in the same AI conversation.
- Optional .agents/skills/android-investigator/SKILL.md for Codex-compatible investigation; not needed for ZIP upload to another AI.
- ADBMedic-Followup.ps1 / Followup-ADBMedic.ps1: closed check catalog, strict JSON keys/types/ranges, case/device/build binding, local confirmation, unique rounds, request/result records and separate ZIPs. No arbitrary commands from model text.
- Installer downloads all required source/agent files pinned to one revision; ordinary bootstrap/report/folder flow remains. User READMEs only gain a short follow-up link. Current rules replace contradictory historic export bans.
- Source protections retained and extended to generated case metadata, stderr/evidence/followups. Positive manifest and source archives never include real sessions or diagnostic ZIPs.

## Verification

Windows PowerShell 5.1: full scripts/Run-CI.ps1 passed, covering offline smoke, source privacy, legacy compatibility, summary, handoff, investigation, runtime, installer and launch suites. Targeted suites are repeated after relevant fixes; exact final assertion counts and CI reference are recorded below before acceptance.

Demonstrated with synthetic inputs only: original byte/hash preservation including BOM/binary/invalid UTF-8, separate concurrent native stdout/stderr, native nonzero exit, bounded timeout with partial bytes, over-64-MiB evidence, hashes/sizes of every ZIP member, Unicode/spaced paths, charging snapshot with unknown idle discharge, explicit failed/unsupported commands, all-failed dossiers, bounded derived lines without raw truncation, invalid/injected JSON fields/types/ranges, PID limits, mismatched case/device/build, multiple preserved rounds, no unsolicited app-content files, no automatic network/cloud/browser calls, and source-only publication protection.

PowerShell 7 is not installed locally; the required PR CI matrix runs it separately. The standard Python skill validator is unavailable because no working local Python interpreter was found. The skill frontmatter/name/description were reviewed against that validator and checked in the synthetic suite; this is not a claim of Python-validator execution or independent behavioral skill evaluation.

## Remaining limits

- No live phone or actual ADB connection was used in implementation verification. OEM command support, permissions and the quality of an external AI diagnosis require owner acceptance.
- This is private, intentionally identifiable evidence. Technical dumps/logs can incidentally contain sensitive information. The baseline does not request communications/app content, and no archive is automatically uploaded.
- Native adb.exe capture preserves bytes. PowerShell function wrappers are a marked text-adapter compatibility path and cannot establish native transport fidelity.
- Disk exhaustion, abrupt termination or filesystem errors can prevent a final ZIP. Original and partial capture files remain local; command limits/errors are explicit. Arbitrarily large ZIP/ZIP64 boundary cases above 4 GiB were not exercised locally.
- Derived analysis is initially battery-focused; raw evidence covers other services. Unknown values are not guessed. Two USB-connected snapshots do not establish unplugged idle drain; controlled unplugged observations remain user-assisted.
- Follow-up commands may be unsupported or denied on some devices. Native stack attachment is unavailable; no root/debugger escalation. PID reuse and statistics-window resets must be checked by the investigator before comparison.
- Device/build changes require a fresh baseline. Legacy cases missing a local binding cannot run correlated follow-ups. Existing exports are not overwritten.

## Minimal owner acceptance procedure

1. Test the PR/local branch, not the GitHub main launch command before merge. Open Windows PowerShell in this checkout and run `.\bootstrap.ps1` without extra flags.
2. Authorize USB debugging on the chosen phone, consent to collection and describe a symptom (or a general check). Wait for completion; choose 2 to open exports. The report should not open automatically.
3. Confirm ADBMedic-report.zip, START-PROMPT.txt and the collection report exist. Attach the ZIP and starter to your chosen AI. Check that its language matches Windows or your explicit request, it cites evidence, and it does not assume a cause or invent missing measurements.
4. Ask the AI for one relevant follow-up request. Save its JSON. In the same script folder run `.\Followup-ADBMedic.ps1`; provide the ORIGINAL session folder (parent of exports) and JSON path. Review the listed checks and confirm only the intended measurements.
5. Attach the new follow-up ZIP to the same chat. Verify same case ID, new round ID, preserved original ZIP, explicit command failures when applicable, and a revised conclusion grounded in the new evidence. No data should upload automatically or commands change phone settings.
6. Report phone/Android version, collection completion/failures, whether ZIP/report/prompt were found, AI conclusion quality, and follow-up usability. Keep real archives out of GitHub issues/PRs.

## Local results at branch publication

Windows PowerShell 5.1 full run: PASS. Final affected suites: handoff 359, investigation 328 assertions; other suites: privacy 66, legacy compatibility 127, summary 26, runtime 139, installer 41, launch 4. Total: 1090 explicit assertions plus smoke checks. All 69 local Markdown links passed. Native byte transport and timeout tests launched only a synthetic PowerShell child, never ADB.
