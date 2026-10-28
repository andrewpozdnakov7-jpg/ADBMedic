# Evidence interpretation and local follow-up

UID/PID/TID, package/process names, service identifiers, build details and timestamps are intentionally retained. Shared UIDs can represent multiple packages; PIDs can be reused. Verify process starttime/name before comparing /proc CPU ticks. An app appearing in a counter is not proof of fault, surveillance or malware.

Preserve the original unit, section and time window. Command execution time is not the duration of a historical counter. BatteryStats mAh are modeled estimates, not measured current or battery-health measurements. Wake-lock acquisitions, alarm deliveries, wakeups, jobs and Binder transactions are different events. Do not sum overlapping timers or different statistics windows, derive energy per event, or turn absent values into zeros. Validate any inconsistent aggregate before ranking applications. CPU usage may span multiple cores. A current thermal snapshot does not establish thermal history.

USB collection can charge and load the phone. Idle discharge needs a user-assisted unplugged start/end observation, with times, battery levels, screen/activity/network conditions and later ADB reconnect. Do not reset batterystats, force idle, run jobs, kill processes, reboot, root, flash, clear data or change settings through ADB to simplify diagnosis. Two cumulative snapshots are not automatically a valid delta; compare common windows and actual charging conditions first.

The collector's capability evidence and actual command status matter. Unsupported syntax, denied permissions or empty responses do not establish absence of a problem. Baseline never requests unrestricted logcat, bugreports or app contents. A targeted logcat check explicitly selects system/crash buffers, PID and the last 200 records; it can still incidentally include sensitive information. GNSS/radio checks can reveal location/network details. Explain that before the owner confirms. The archive is not anonymized and must not be posted to GitHub.

## Running a follow-up request on Windows

The AI returns JSON, not an executable command string. Save it as `followup-request.json` anywhere outside the source repository. Keep the original installed ADBMedic version and original case folder. The collector has no automatic AI connection.

In Windows PowerShell, enter the folder containing the installed ADBMedic scripts and run:

```powershell
.\Followup-ADBMedic.ps1
```

It asks for the ORIGINAL session folder and saved JSON path, shows the requested check IDs and relevant notices, then asks for confirmation. The original folder is the parent of the `exports` folder opened by option 2 after collection. To find the installed scripts, use:

```powershell
explorer.exe (Join-Path $env:LOCALAPPDATA 'ADBMedic\app')
```

Open the version folder used for the baseline. Do not select a different phone or edit case.json to bypass device/build correlation. Existing cases missing a local device binding need a new baseline. Results appear in the original case's `followups` subfolder with a separate `exports` folder. The terminal prints the ZIP location. Attach that ZIP to the same AI conversation. The original case and previous rounds are never overwritten. No arbitrary commands from the AI are executed.

If a check is blocked, report its command outcome and stderr. Do not request root or disable safeguards. If the structured runner cannot perform a needed measurement, give a short, focused read-only manual procedure adapted to confirmed device capabilities, explain its privacy implications, and have the owner decide. An unavailable check is a limitation, not a reason to claim a diagnosis.
