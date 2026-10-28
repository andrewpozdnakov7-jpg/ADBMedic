# IMPLEMENTATION-003 — Interactive investigation and grounded visuals

## Scope and architecture

TASK-003 adds a thin local controller around the existing TASK-002 collector, packager and diagnostic runner. No new diagnostic check engine, cloud connector, watcher, mandatory GUI dependency or privilege escalation was added. Stop at a separate PR for owner acceptance; do not merge or create a Release.

ADBMedic-Interactive.ps1 provides the persistent case menu, bounded file/paste imports, optional Windows JSON picker with typed-path fallback, explicit Downloads selection, human-readable confirmation and restart/resume. Start-ADBMedic.ps1 invokes it before ADB initialization on resume, and after baseline packaging in the same window. bootstrap/installer ship the controller automatically. NoBrowser retains the existing nonpersistent/headless baseline workflow.

The existing ConvertTo-ADBMedicFollowupPlan, catalog and Invoke-ADBMedicFollowupRound still define and execute the checks. Changes to ADBMedic-Followup.ps1 add shared input parsing and safe field/category errors, canonical replay fingerprints, exclusive case locking, original-request evidence and an original-manifest hash reference. Diagnostic command definitions, numeric limits and collection semantics were retained. Both menu and optional advanced CLI call Invoke-ADBMedicConfirmedFollowup. The imported JSON never becomes executable PowerShell. The optional picker uses a constant application-owned script in an STA runspace; no request text is passed as code.

JSON input is at most 64 KiB strict UTF-8. Files and ancestors must be regular local/non-reparse paths. Entire fenced JSON blocks are accepted; surrounding prose is rejected with safe guidance. Paste ends with END or cancels with CANCEL. Original validated file bytes/BOM and paste source are retained in private round evidence. Schema/case/fields/check IDs/types/ranges and catalog availability are validated before ADB access; the UI exposes fixed field names, never raw values. Reason text, including code-like characters, remains data.

Replay identity includes case/schema, trimmed reason and normalized validated measurement plans. Object/check order, whitespace and omitted/explicit default parameters do not evade detection. The case lock prevents concurrent runners. Completed/collecting/interrupted requests are not silently repeated. A failed device-binding read before requested measurements can be retried. A justified repeat needs a new measurement purpose in reason. Existing legacy request records are checked too.

Resume discovers only the fixed local application session root, validates schema, supported collector/interactive version, target binding and saved ZIP manifest identity, and offers the newest valid case or explicit selection. Equal creation times require a choice. Older unbound/incompatible cases get an explanation without modification. The newest available ZIP is offered; incomplete rounds remain visible. A compatible unexported baseline can retry packaging existing evidence without recollection. Original ZIPs are not overwritten.

INVESTIGATE.md, Skill, START-PROMPT and agent rules now require downloaded JSON where supported AND a standalone JSON code block, same-window option 3 and normal relaunch/Resume. Six user READMEs explain this briefly in their existing languages. Charts require reliable numeric/time/unit evidence and provenance; no synthetic diagnosis, invented time-series, interpolated precision or confusion between historical charge and per-app energy. Native AI charts are preferred; honest tables are allowed when chart rendering is unavailable.

## Changed areas

- Controller/launch: ADBMedic-Interactive.ps1, Start-ADBMedic.ps1, Followup-ADBMedic.ps1, bootstrap.ps1, Install-ADBMedic.ps1.
- Shared boundary/evidence: ADBMedic-Followup.ps1, ADBMedic-Handoff.ps1, ADBMedic-Evidence.ps1. The collector metadata version is 0.3.0-dev; original evidence streaming/hashes remain intact.
- Instructions/docs: INVESTIGATE.md, agent/investigation-rules.md, optional android-investigator Skill, AGENTS/manager rules, SAFE-HANDOFF/DEVELOPMENT and six READMEs.
- Source protection: ignore/forbidden paths for investigation.lock and request-source.txt; positive source manifest. No privacy exception for real diagnostic data.
- Tests: Interactive.Tests.ps1, existing runtime/installer/investigation adaptations, synthetic VisualCases.json, Run-CI integration.

## Verification results

Final automated suite counts, CI and PR references are recorded after verification below. All development verification uses synthetic data/mocked ADB. Existing privacy/hook/source-archive gates remain mandatory. No phone, personal diagnostics, actual Downloads scan or live cloud analysis was used.

Interactive regression covers baseline menu 3, downloaded file and fenced/unfenced multiline paste through the same parser/runner; one confirmation; battery_timeline plus jobs_alarms; a separate same-case/new-round ZIP; original ZIP/hash preservation; original JSON/BOM; actual failed-command status; all supported import cancellations, picker fallback, quoted Unicode/spaced paths and explicit multi-file Downloads choice; missing Downloads, size bounds and reparse rejection; strict input/injection errors; replay across formatting/defaults/restart and an interrupted attempt; wrong/missing/unauthorized/disconnected device or ADB; changed build and reconnect retry; concurrent case lock; latest/other/ambiguous resume, incompatible legacy metadata, newest round selection and packaging retry without diagnostics. Tests never open a real picker or read a real Downloads folder.

## AI instruction smoke evaluation (synthetic, text-only)

The implementing AI read tests/fixtures/VisualCases.json under the updated investigator contract. This is a documented primary-agent smoke evaluation, not an independent external-model or graphical-client evaluation. In this text-only test the permitted honest-table fallback was used.

Positive case: battery charge (%) against local DEVICE time, 2000-01-01, timezone +03:00. Source evidence/synthetic-history.txt, recorded points only:

| Local time (+03:00) | Charge (%) | USB at recorded point | Source line | Value kind |
| --- | --- | --- | --- | --- |
| 00:00 | 80 | disconnected | 1 | recorded |
| 02:00 | 75 | disconnected | 2 | recorded |
| 03:00 | 72 | connected | 3 | recorded |
| 04:00 | 85 | connected | 4 | recorded |
| 08:00 | 68 | disconnected | 5 | recorded |

Interpretation: the recorded charge rises between the USB-connected 03:00/04:00 samples and is lower at 08:00. There are no intermediate points in the declared 04:00–08:00 gap; no 06:00 charge or precise connection/disconnection transition is invented. USB was observed connected at the listed points, not proven continuous throughout an interpolated interval. These are battery-charge observations, not an application energy attribution or a root-cause diagnosis. Source/timezone/units/recorded status and gaps are explicit.

Negative case: evidence/synthetic-battery-state.txt:1 has only 68% at 08:00 +03:00, with USB connected and no history. Response: no charge-over-time graph, discharge slope, idle-drain conclusion or per-app ranking can be supported. Request relevant catalog measurements if needed. A current value is not a time-series. External AI chart quality and graphical rendering remain owner acceptance items.

## Minimal owner acceptance

1. Test this PR/local branch with bootstrap.ps1. Collect a baseline and keep the same window open; option 3 must be visible. Nothing should open automatically.
2. Attach ZIP and START-PROMPT to the selected AI. Check language, evidence citations and an honest chart/table when supported. Its follow-up should be a downloadable JSON plus a standalone JSON block.
3. Choose 3 in the same ADBMedic window. Test downloaded JSON/file picker and paste (finish END). No case/version folder should be requested. Review the human-readable measurements, confirm once, reconnect/unlock the same phone and authorize USB if needed.
4. Choose 2 to find the new ZIP and attach it to the same AI conversation. Verify same case ID, new round ID, original-manifest reference, actual statuses and unchanged original ZIP. Repeat with a genuinely new request.
5. Exit 0 and relaunch normally; choose Resume or select another case without a path. No new baseline should run merely to resume/view a case. After approval/merge the normal GitHub command provides this flow; before merge main still has the prior interface.
6. Check malformed/wrong-case/replayed JSON errors, cancellation and reconnect handling. Keep personal ZIPs out of GitHub. Report UX failures and AI chart/diagnostic quality privately.

## Remaining limitations

- Native picker/clipboard/console paste behavior and real OEM/ADB permissions need manual Windows/device acceptance; automated tests mock those UI/device boundaries.
- Graphical chart rendering and external model behavior were not independently executed. The two synthetic instruction cases demonstrate the table/no-invented-chart branches only.
- Existing TASK-002 limits remain: arbitrary >4 GiB archive boundaries and real phones are unverified; interrupted/storage failures can prevent a final ZIP while keeping raw/partial evidence. No privilege escalation or automatic unplugged observation was added.
- A request whose measurements may have begun is blocked from replay after restart. Ask for a new justified request rather than silently repeating it. Corrupt/incompatible history fails closed.
- No MCP, automatic conversation polling/uploads, personal-app-content collection, Releases or PR merge.

## Final local verification

Windows PowerShell 5.1 full scripts/Run-CI.ps1: PASS. Assertions: privacy 66, legacy safe-export compatibility 127, summary 26, handoff 359, investigation 329, interactive 68, runtime 140, installer 41, launch 4 — total 1160, plus smoke checks. Markdown links: 70 checked, PASS. git diff --check: PASS. PowerShell 7 is covered by the required PR CI matrix because it is not installed locally. All ADB/UI/Downloads cases were synthetic/mocked. Branch: task-003-interactive-investigation. PR and source commit references are recorded after publication.


## Review references

[Pull Request 16](https://github.com/andrewpozdnakov7-jpg/ADBMedic/pull/16), branch task-003-interactive-investigation. [Implementation source commit](https://github.com/andrewpozdnakov7-jpg/ADBMedic/commit/a91faf882b8270ae0697daab9c38e9f8e4d6af2c). The following report-only commit records these references. Required Windows PowerShell 5.1/7, privacy and source-archive CI results are attached to the current PR head. Do not merge before owner acceptance; main still has the accepted TASK-002 interface.
