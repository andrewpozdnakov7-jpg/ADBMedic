# Safe manual handoff v1

The owner authorized a validated ZIP and assistant instructions after TASK-001. This permits a projection of supported measurements, not raw-log export or automatic AI access. No browser or folder opens until the user chooses a menu item.

## User flow

After collection, the terminal announces that the report is ready, explains manual AI handoff only when validation succeeds, and offers 1 (private local report), 2 (prepared export folder), Enter (finish). A failed window launch returns to the menu. Unsupported measurements leave a private local report and a clear no-share warning; no fabricated ZIP is offered.

The prepared folder contains `ADBMedic-report.zip` plus the four share documents. The ZIP contains exactly `REPORT.md`, `REPORT.html`, `facts.json` and `MANUAL-ANALYSIS-PROMPT.md`. The private report and raw capture files stay outside it. The private report also contains the P-label/process-name mapping needed to interpret an assistant's recommendations. Missing mappings are explicitly unknown; process names are never guessed.

The user manually attaches the ZIP to a suitable AI chat. A chat unable to read ZIP can receive the extracted Markdown, JSON and instruction file. No provider integration, credential or automatic upload is added.

## Allowed measurements

- Fixed schema version, fixed request category (battery/cpu/camera/sensors/general), Russian/English answer language and nominal 2-second collector interval.
- At most three recognized Toybox CPU samples: normalized whole-CPU busy percent, plus up to 15 anonymized subject groups with per-core CPU percentages. More than 100% for a group is possible. Labels group observed Android users, not necessarily single applications.
- Recognized battery time-on-battery and screen-off windows rounded down to minutes; optional estimated aggregate mAh and up to 15 subject estimates. These are model estimates with potentially different time bases, not proof of sustained drain.
- Optional powered state, wakefulness enum and thermal severity 0–6. Missing fields remain null, never fabricated zeroes.

Names/packages, actual UID/PID, device model/fingerprint/serial, capacity, wall-clock times, hashes of identifiers, original complaint text, network addresses, raw logs, native stacks and camera/sensor dumps are excluded. The free-text complaint selects only a fixed task category. P-labels have meaning only within one session and must not be assumed stable across separate ZIPs.

## Validation boundary

Input reads use only fixed filenames, strict UTF-8 and a 16 MiB per-file limit. UNC paths and reparse points in the session path or input files are rejected. Known malformed measurements, contradictory windows and duplicate energy entries fail closed. Unrecognized source sections are not copied; absent supported measurements block export.

The independent output gate reparses a closed JSON schema with explicit field names, primitive types, numeric ranges, enum values, array limits and time consistency. It requires canonical JSON, exactly generated Markdown/instructions, and an independently rendered deterministic HTML report. Extra fields/files or appended text are rejected. There is no regex-based claim that arbitrary raw data became anonymous.

Only four exact leaf names enter the ZIP. Entry timestamps are fixed rather than copied from collection time. After creation, entries are checked for duplicates, path/size violations and decompression bounds, extracted to a separate directory and validated again. Existing export directories are not overwritten or silently reused. Final export becomes visible only after both gates pass.

The assistant instruction requires a plain-language conclusion, field-based evidence, confidence, 3–5 prioritized reversible steps, detailed user feedback and a concrete next measurement if needed. It forbids invented app names, unwarranted malware/hardware claims, root/flash/reset/data-loss/system-service operations and requests for private logs. CPU snapshots, estimated energy and collection over USB must be interpreted with their limits.

This v1 covers only the listed formats and metrics. OEM/Android variants can be unsupported. Numeric workload patterns can still be correlated with external observations; no absolute anonymity or independent external security audit is claimed. Real-device verification remains the owner's job. The raw-export and automatic-cloud holds remain in force.
