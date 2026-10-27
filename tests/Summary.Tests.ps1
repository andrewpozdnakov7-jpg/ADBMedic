$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'ADBMedic-Summary.ps1')
$stage=Join-Path $root ('.test-work/summary-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage)|Out-Null
$passed=0
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw ('Summary test failed: '+$Message)};$script:passed++}
function Write-Fixture([string]$Name,[string]$Text){[IO.File]::WriteAllText((Join-Path $stage $Name),$Text,([Text.UTF8Encoding]::new($false)))}
try{
    $text=@'
Battery History:
  TEST_HISTORY_EVENT: alarm, job, wake lock
  Uid u0a123: 999
Statistics since last charge:
  Time on battery: 2h 3m 4s 500ms (50%) realtime
  Time on battery screen off: 1h 0m (25%) realtime
  Estimated power use (mAh):
    Capacity: 4000, Computed drain: 10, actual drain: 0-100
    Uid u0a123: 3 (cpu=1)
    Uid 10124: 2 (cpu=1)
  u0a123:
    Wake lock TEST:TAG: 1m 2s 3ms partial (4 times) max=1, 2ms background partial (1 times) realtime
    Job TEST_JOB: 3s realtime (2 times)
    Job TEST_JOB: completed 6 times
    Apk com.example.synthetic:
      Wakeup alarm TEST_ALARM: 7 times
  10124:
    Wake lock TEST_ZERO: 0ms partial (0 times) realtime
  u10a123:
    Apk com.example.otherprofile:
      Wakeup alarm TEST_OTHER: 1 times
Statistics since last reset:
  Estimated power use (mAh):
    Capacity: 4000, Computed drain: 1, actual drain: 0-10
    Uid u0a123: 4
  u0a123:
    Job TEST_JOB: 1ms realtime (1 times)
Other section:
  1234:
    Wakeup alarm TEST_NOT_UID: 999 times
'@
    Write-Fixture 'battery.txt' $text
    Write-Fixture 'packages.txt' "package:com.example.synthetic uid:10123`npackage:com.example.shared uid:10123`npackage:com.example.second uid:10124"
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert ($a.windows.Count -eq 2 -and $a.energySections.Count -eq 2) 'statistics windows remain separate'
    Assert ($a.energySections[0].entries.Count -eq 2 -and $a.energySections[0].entries[0].valueMah -eq 3) 'history lines are not mistaken for energy'
    Assert ($a.energySections[0].quality -ceq 'parsed-not-diagnosed') 'consistent estimates do not imply diagnosis'
    Assert ($a.energySections[1].quality -ceq 'needs-review') 'conflicting section is marked for review'
    Assert (@($a.issues|Where-Object code -eq 'uid-energy-exceeds-aggregate').Count -eq 1) 'single UID exceeding its aggregate is visible'
    Assert ($a.energySections[0].entries[0].source.line -eq 9) 'energy source line refers to the original file'
    Assert ($a.windows[0].durations[0].seconds -eq 7384.5) 'duration units retain milliseconds'
    $wake=@($a.counters|Where-Object {$_.uid -eq '10123' -and $_.kind -eq 'partial-wakelock'})
    Assert ($wake.Count -eq 1 -and [Math]::Abs($wake[0].durationSeconds-62.003) -lt 0.00001 -and $wake[0].count -eq 4) 'primary partial wake time/count excludes the background sub-timer'
    Assert ($wake[0].tag -ceq 'TEST:TAG') 'tag colons do not change the duration boundary'
    Assert (@($a.counters|Where-Object kind -eq 'job-timer-start').Count -eq 2) 'job timer starts are separate from completion rows and windows'
    Assert (@($a.counters|Where-Object {$_.kind -eq 'wakeup-alarm' -and $_.count -eq 7}).Count -eq 1) 'wakeup alarm counter is typed explicitly'
    Assert (@($a.counters|Where-Object {$_.tag -eq 'TEST_NOT_UID'}).Count -eq 0) 'unknown top-level sections cannot become UID counters'
    $zero=$a.counters|Where-Object tag -eq 'TEST_ZERO'
    Assert ($zero.count -eq 0 -and $zero.durationSeconds -eq 0) 'explicit zero remains a measured zero'
    Assert (($a.apps|Where-Object uid -eq '10123').packages.Count -eq 2) 'shared UID identity stays plural'
    Assert (($a.apps|Where-Object uid -eq '1010123').packages[0].package -ceq 'com.example.otherprofile') 'UID-scoped Apk maps other users without guessed names'
    Assert ((ConvertTo-ADBMedicUid 'u0i12') -ceq '99012' -and (ConvertTo-ADBMedicUid 'u0s1000') -ceq '1000') 'isolated and system UID forms are normalized'
    Assert ($null -eq (ConvertTo-ADBMedicUid 'TEST_INVALID_UID')) 'invalid UID is not assigned to an application'
    $md=New-ADBMedicSummaryMarkdown $a en
    Assert ($md.Contains('evidence/battery.txt:9') -and $md.Contains('needs-review') -and $md.Contains('job-timer-start')) 'summary cites facts and exposes quality/counter semantics'
    Write-Fixture 'battery.txt' "Statistics since last charge:`n  Estimated power use (Wh):`n    Computed drain: 10`n    Uid u0a123: 1"
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert ($a.energySections[0].entries.Count -eq 0 -and @($a.issues|Where-Object code -eq 'unsupported-energy-unit').Count -eq 1) 'unknown energy units are not silently called mAh'
    Write-Fixture 'battery.txt' "Statistics since last charge:`n  Estimated power use (mAh):`n    Computed drain: 10`n    Uid u0a123: 1u`n    Uid u0a124: 2 Wh"
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert ($a.energySections[0].entries.Count -eq 0 -and $a.coverage.unparsedCandidates -eq 2) 'unknown value suffixes are rejected without changing raw data'
    Write-Fixture 'battery.txt' "Statistics since last charge:`n  Estimated power use (mAh):`n    Computed drain: 10`n    Uid u0a123: 1`n    Uid 10123: 2"
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert (@($a.issues|Where-Object code -eq 'duplicate-uid-energy').Count -eq 1) 'duplicate UID rows are flagged rather than silently merged'
    Write-Fixture 'battery.txt' "Statistics since last charge:`n  Estimated power use (mAh):`n    Computed drain: 10`n    Uid u0a123: 1`n    Uid u0a124: 2u`n  Estimated power use (mAh):`n    Computed drain: 20`n    Uid u0a123: 5"
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert ($a.energySections[0].quality -ceq 'partial-extraction') 'a partial UID extraction cannot appear complete'
    Assert ($a.energySections.Count -eq 2 -and $a.energySections[0].endLine -eq 5 -and $a.energySections[1].entries[0].valueMah -eq 5) 'repeated energy sections retain separate values and exact boundaries'
    Write-Fixture 'battery.txt' ("Statistics since last charge:`n  Estimated power use (mAh):`n"+((1..12|ForEach-Object{'    Computed drain: 10'}) -join "`n"))
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert ($a.energySections[0].aggregates.Count -eq 8 -and $a.coverage.outputLimited) 'repeated aggregates are bounded and the limit is explicit'
    Write-Fixture 'battery.txt' 'TEST_UNKNOWN_OEM_FORMAT'
    $a=Get-ADBMedicBatteryAnalysis $stage
    Assert ($a.status -ceq 'unsupported' -and $a.energySections.Count -eq 0) 'unsupported OEM format is explicit and has no invented measurements'
    Assert ($null -eq (ConvertTo-ADBMedicDurationSeconds '1h TEST_UNKNOWN_UNIT')) 'unknown duration text does not yield a partial conversion'
    Write-Output ('Offline summary tests: PASS ('+$passed+' assertions).')
}finally{
    $target=[IO.Path]::GetFullPath($stage);$prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe cleanup target.'}
    if([IO.Directory]::Exists($target)){[IO.Directory]::Delete($target,$true)}
}
