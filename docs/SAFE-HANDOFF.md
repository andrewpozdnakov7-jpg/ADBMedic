# Manual diagnostic handoff v2

The owner changed the product goal: preserve useful evidence so a manually chosen AI can investigate causes, explain real application energy use, propose treatment and prescribe follow-up read-only ADB examinations. Source/GitHub privacy gates remain separate and mandatory. Diagnostic ZIPs never enter Git, CI source artifacts or automatic uploads.

## User flow

Run bootstrap without arguments, consent to collection and describe the complaint. After collection, choose 1 to open the report, 2 to open the export folder, or Enter to exit. The app opens nothing automatically. Review ADBMedic-report.zip and manually attach it to an AI you trust. The collector does not run AI recommendations.

After a successful export, the terminal prints a short starter prompt to copy into the AI chat together with the ZIP. The same text is in the report and START-PROMPT.txt beside the archive and inside it. It points to the full analyst instructions, requests a diagnosis/action plan/follow-up examinations, states the answer locale and explains what to do if the archive cannot be opened. It is not printed when export fails.

The archive contains REPORT.md, REPORT.html, facts.json (schemaVersion 2), MANUAL-ANALYSIS-PROMPT.md, START-PROMPT.txt and selected evidence text files. The complete AI-ANALYST.md contract is embedded in the full prompt, with the selected answer language. The project link is optional context; browsing is not required. Without ZIP support, attach the extracted documents and relevant evidence files.

The AI answer defaults to the full Windows display locale (or an explicit collector language override), stored in facts.json.language. The separate interfaceLanguage field describes the collector's Russian/English text. A user request for another language in the AI chat takes precedence; English evidence/documentation must not change the answer language.

## Evidence and interpretation

- facts.json preserves the complaint, device model/Android, session capture time and per-source collection result/size/start/end/exit code. Capture intervals describe command execution, not the historical counter period. Older sessions without capture metadata explicitly have null times.
- Original CPU, top, batterystats, current battery state, power, thermal, camera, sensors, package-to-UID mapping, alarm, jobscheduler and deviceidle text is retained when available. Real names, UID/PID, tags and counter details are intentional. Empty, failed and missing files are explicit; unsupported OEM text is retained for analysis rather than silently discarded.
- No parsed mAh summary is presented as a verified balance. The AI must check source section, model, units and window before comparing totals/entries. Short CPU snapshots cannot establish a day's drain. Shared UID attribution and USB power state matter.
- No full getprop, build fingerprint, ADB serial, bugreport, logcat, credentials file or arbitrary session directory is added by the collector. Detailed service dumps and complaints can still contain sensitive information: this is a private archive, not an anonymous public artifact.

## Boundaries

Only fixed source filenames are read. Inputs require strict UTF-8, no NUL, regular files, a non-reparse local session path and at most 64 MiB per file / 128 MiB of evidence. The same per-file limit applies when validating ZIP entries; evidence is not silently truncated. A 16 MiB limit was too small for real batterystats dumps. Limit, secret, missing-context and input errors have separate safe messages identifying only known filenames, never matched values or private paths. The scanner blocks known credential/key patterns; it does not claim universal secret detection or anonymization. Unknown extra files are ignored. Existing exports are never overwritten. ZIP entries are checked against the expected list and their exact text is compared before the export becomes visible.

The package-to-UID query uses `pm list packages -U --user current` to avoid requesting inaccessible secondary profiles. Other users' packages can remain unmapped. Failed old-session package queries remain explicit; rebuilding an archive cannot recover data that was not collected.

Source publication uses the separate Worktree/Staged/History gates and a positive source manifest. The legacy numeric/P-label v1 projector remains for compatibility tests only; Package-ADBMedic.ps1 now creates the diagnostic v2 archive. Automatic cloud analysis remains disabled.

## AI result

The required answer contains a diagnostic conclusion, application evidence table with exact counter types/windows/source references, ranked explanations, 3-5 reversible treatment steps, focused additional commands when needed, and a user feedback template. It must not invent counters, derive energy per call without a valid model, guess application identities or claim every top consumer is faulty. Follow-up commands are Windows PowerShell compatible and read-only; no reset/root/flash/kill/uninstall/settings changes are diagnostic steps.

Validation uses synthetic fixtures. A real-device run and the quality of an external AI's conclusion still need user acceptance. An old schema-1 archive does not gain new data when source is updated: collect a new session.
