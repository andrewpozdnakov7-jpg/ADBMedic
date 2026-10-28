# Local investigation handoff v3

ADBMedic creates an offline private case ZIP. Real UID/PID/TID, package/process names, vendor/build details, service identifiers and timestamps are retained byte-for-byte. No anonymization or secret-pattern filter is applied to the private ZIP. No automatic uploads, model account, API key or Codex installation is required.

## Collection and integrity

The fixed baseline captures CPU/top/threads, battery state/statistics, power/idle, thermal, camera/sensors, jobs/alarms, package identities, selected build properties, device clock/uptime, available services, display/audio, connectivity/Wi-Fi/network statistics and storage state. It never requests SMS, notification text, contacts, conversations, screenshots, app files, unrestricted logcat or a full bugreport. Technical dumps can incidentally contain sensitive information; the archive is not anonymous and must not be posted publicly.

Native ADB stdout/stderr are separate byte streams: no decoding, Out-String, error prefixes, BOM removal, newline normalization or diagnostic size cap. PowerShell function wrappers use an explicitly marked text-adapter compatibility path; use official native adb.exe for literal device output. Nonzero exits, missing permissions, unsupported commands and timeouts retain original responses with honest outcomes. Baseline timeout defaults to 1200 seconds per command; Start-ADBMedic.ps1 accepts CommandTimeoutSeconds from 1 to 86400. Timeout ends the local client, never a phone process. Disk exhaustion, abrupt shutdown or I/O failure can prevent packaging; completed/partial source files remain local.

Copy/hash/ZIP writing and re-reading are streamed. SHA-256 verifies each uncompressed ZIP member before exports becomes visible. Existing exports are never overwritten. Only fixed baseline/control names and validated capture names are included, never a whole directory. Inputs must be regular local files with no reparse paths. Derived parsers have visible extraction limits and skip overlong lines; original evidence is not truncated.

## Case files

manifest.json records schema/case/round identity, collector version, timezone-bearing capture times, capabilities, command argv/status/errors/completeness/fidelity, file sizes and hashes, and omissions. Its own hash is excluded to avoid self-reference. device.json holds selected build/model properties with source references. conditions.json records reliably parsed battery scale/percentage, power-source flags, wakefulness and uptime. Unknown values stay unknown; wakefulness is not a verified screen state. A USB snapshot does not establish idle discharge or battery health.

symptom.txt contains the complete complaint; facts.complaint is a bounded display preview only. facts.json v3 and SUMMARY.md retain battery windows, typed counters, real UID/package mappings and provenance. Modeled mAh are explicitly estimated. Failed sources are excluded from derived extraction; malformed collection metadata is retained with an issue. Raw unsupported/OEM data stays in evidence. REPORT.md/html is a collection summary, never a fabricated diagnosis.

INVESTIGATE.md and agent/ provide self-contained investigation rules, catalog and request example. START-PROMPT.txt is beside and inside ZIP and printed after success. Answer language is full Windows locale, overridden by an explicit chat request. The report/folder menu opens nothing automatically.

## Owner-authorized local follow-up

The AI selects 1–3 check IDs in adbmedic.followup.v1 JSON for the exact case. Followup-ADBMedic.ps1 asks for original session/request paths, validates object keys and integer parameters, displays checks/notices, and requires confirmation. No executable fields, shell commands, paths or scripts from the model are accepted. Request reason is data only.

Selected ADB serial and freshly captured build fingerprint must match the baseline local case.json binding. A build update or missing binding requires a new baseline. Each round has a unique ID, request/results metadata, per-command outcomes/times, sample power conditions and separate validated ZIP under followups. Original case/rounds remain intact. Attach the new ZIP to the same AI conversation. Deltas and causal conclusions remain the investigator's responsibility; no counters are reset.

See [local procedure](../agent/investigation-rules.md) and [check catalog](../agent/check-catalog.json). Native stack attachment is unavailable. top/logcat syntax and permissions vary by phone; failures are evidence, not zeros. Targeted logcat intentionally selects system/crash buffers, one PID and the last 200 records, with a notice. GNSS/radio checks may reveal location/network details. USB-connected repeated snapshots do not measure unplugged idle discharge. Privileged debugging, automated unplugged observation and MCP are outside this implementation.

## Published source

Private export policy is independent of public source protection. Positive source-manifest.json, ignore rules, Worktree/Staged/History audits, local hooks and verified source archives remain mandatory. Real cases/ZIPs never belong in Git or CI artifacts. Tests use synthetic data only.