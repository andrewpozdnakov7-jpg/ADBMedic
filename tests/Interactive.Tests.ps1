$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'ADBMedic-Interactive.ps1')
$stage=Join-Path $root ('.test-work/interactive-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage)|Out-Null
$savedLocalData=$env:LOCALAPPDATA;$env:LOCALAPPDATA=$stage
$data=Join-Path $stage 'ADBMedic/data';[IO.Directory]::CreateDirectory($data)|Out-Null
$test=@{Passed=0;Answers=(New-Object 'System.Collections.Generic.Queue[string]');Prompts=@();Calls=@();Opened=@();Network=0;PickerStatus='selected';PickerPath=$null;Downloads=(Join-Path $stage 'TEST Downloads');MissingAdb=$false;Device='ready';Build='TEST_BUILD';FailedJobs=$false}
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw ('Interactive test failed: '+$Message)};$test.Passed++}
function Answers([string[]]$Lines){$test.Answers.Clear();$test.Prompts=@();foreach($line in $Lines){$test.Answers.Enqueue($line)}}
function Read-Host {param($Prompt)
    $test.Prompts+=,[string]$Prompt
    if(-not $test.Answers.Count){throw 'Synthetic answer queue exhausted.'}
    return $test.Answers.Dequeue()
}
function Start-Process {param($FilePath,$ArgumentList) $test.Opened+=,[pscustomobject]@{File=$FilePath;Arguments=$ArgumentList}}
function Invoke-WebRequest {$test.Network++;throw 'Unexpected synthetic network call.'}
function Invoke-RestMethod {$test.Network++;throw 'Unexpected synthetic network call.'}
function codex {$test.Network++;throw 'Unexpected synthetic AI call.'}
function Show-ADBMedicRequestFilePicker {param($Title) return [pscustomobject]@{Status=$test.PickerStatus;Path=$test.PickerPath}}
function Get-ADBMedicDownloadsDirectory {return $test.Downloads}
function Get-Command {param($Name,$ErrorAction)
    if($Name -eq 'adb' -and $test.MissingAdb){return $null}
    return Microsoft.PowerShell.Core\Get-Command -Name $Name -ErrorAction SilentlyContinue
}
function adb {
    $test.Calls+=,@($args);$global:LASTEXITCODE=0
    if($args[0] -eq 'devices'){
        switch($test.Device){
            'unauthorized' {return 'TEST_SERIAL unauthorized'}
            'disconnected' {return 'List of devices attached'}
            'wrong' {return 'TEST_OTHER_SERIAL device'}
            default {return 'TEST_SERIAL device'}
        }
    }
    if($args[0] -ne '-s' -or $args[2] -ne 'exec-out'){throw 'Unexpected synthetic ADB command.'}
    if($args[3] -eq 'getprop'){return $test.Build}
    if($test.FailedJobs -and $args[4] -eq 'jobscheduler'){$global:LASTEXITCODE=13;return 'TEST_PERMISSION_DENIED'}
    if($args[4] -eq 'battery'){return "USB powered: true`nlevel: 70`nscale: 100"}
    return 'TEST_TECHNICAL_EVIDENCE UID 10123 PID 321 TID 322 com.example.synthetic'
}
function New-Case([string]$Name,[string]$Created='2000-01-01T00:00:00+03:00'){
    $session=Join-Path $data ('session-'+$Name);[IO.Directory]::CreateDirectory($session)|Out-Null
    $state=Get-ADBMedicCaseState $session;$state.created=$Created;$state.answerLocale='en-US'
    $record=Invoke-ADBMedicCapture 'adb' @('-s','TEST_SERIAL','exec-out','getprop','ro.build.fingerprint') $session 'build-fingerprint.txt' 5 'device-binding'
    $state.target=[pscustomobject]@{adbSerial='TEST_SERIAL';fingerprintSha256=(Get-ADBMedicHash (Join-Path $session 'build-fingerprint.txt'))}
    $state|Add-Member interactiveVersion 1
    Write-ADBMedicJson (Join-Path $session 'case.json') $state
    Write-ADBMedicJson (Join-Path $session 'collection.json') @($record)
    [IO.File]::WriteAllText((Join-Path $session 'symptom.txt'),'TEST_GENERAL_COMPLAINT')
    $bundle=New-ADBMedicDiagnosticBundle $session en -AnswerLocale en-US
    return [pscustomobject]@{Directory=$session;State=$state;Bundle=$bundle}
}
function Request-Text([string]$CaseId,[string]$Reason='TEST_TIMELINE_AND_JOBS'){
    return (@{schema='adbmedic.followup.v1';case_id=$CaseId;reason=$Reason;checks=@(@{id='battery_timeline'},@{id='jobs_alarms'})}|ConvertTo-Json -Depth 5)
}
function Import-Text([string]$Text,[string]$CaseId){return ConvertFrom-ADBMedicRequestBytes ([Text.UTF8Encoding]::new($false).GetBytes($Text)) $CaseId}
function Reject-Text([string]$Text,[string]$CaseId,[string]$Expected=''){
    $before=$test.Calls.Count;$caught=$false
    try{Import-Text $Text $CaseId|Out-Null}catch{$caught=$true;if($Expected){Assert ($_.Exception.Data['ADBMedicRequestCode'] -ceq $Expected) 'safe typed import error'}}
    Assert ($caught -and $test.Calls.Count -eq $before) 'invalid request cannot reach ADB'
}
try{
    $case=New-Case 'TEST путь с пробелами';$caseId=$case.State.case_id
    $originalZip=Join-Path $case.Bundle.Directory $case.Bundle.ArchiveName;$originalHash=Get-ADBMedicHash $originalZip
    $text=Request-Text $caseId
    $requests=Join-Path $stage 'TEST requests';[IO.Directory]::CreateDirectory($requests)|Out-Null
    $requestPath=Join-Path $requests 'followup-request.json'
    [IO.File]::WriteAllText($requestPath,($text+"`r`n"),[Text.UTF8Encoding]::new($true))
    $test.PickerPath=$requestPath;$test.FailedJobs=$true
    Answers @('3','1','y','2','0')
    $output=@(Show-ADBMedicCaseMenu $case.Directory $case.Bundle en *>&1)
    Assert ($test.Answers.Count -eq 0) 'persistent menu accepts file, confirms once, opens new folder and exits'
    Assert (@($test.Prompts|Where-Object {$_ -eq 'Run these checks? [y/N]'}).Count -eq 1) 'one explicit diagnostic confirmation'
    Assert (-not (($test.Prompts -join '|') -match 'Case folder|session folder|version')) 'case path and collector version are never requested'
    Assert (($output -join "`n").Contains('Attach this NEW ZIP to the SAME AI conversation.')) 'same-chat instruction follows new ZIP'
    Assert ($test.Opened.Count -eq 1 -and $test.Opened[0].File -eq 'explorer.exe' -and $test.Opened[0].Arguments.Contains('followups')) 'folder action targets newest follow-up'
    Assert ((Get-ADBMedicHash $originalZip) -ceq $originalHash) 'original ZIP unchanged'
    $rounds=@(Get-ChildItem -LiteralPath (Join-Path $case.Directory 'followups') -Directory)
    Assert ($rounds.Count -eq 1) 'file import produces exactly one round'
    $manifest=Read-ADBMedicControlJson (Join-Path $rounds[0].FullName 'exports/manifest.json')
    Assert ($manifest.case_id -ceq $caseId -and $manifest.round_id) 'same case and new round identity'
    Assert ($manifest.baselineManifestSha256 -ceq (Get-ADBMedicHash (Join-Path $case.Bundle.Directory 'manifest.json'))) 'follow-up references original evidence manifest'
    Assert (@($manifest.commands|Where-Object {$_.id -eq 'jobs_alarms' -and $_.status -eq 'failed'}).Count -eq 2) 'actual command failure retained for stdout and stderr'
    Assert ((Get-ADBMedicHash $requestPath) -ceq (Get-ADBMedicHash (Join-Path $rounds[0].FullName 'exports/evidence/request.json'))) 'downloaded JSON bytes including BOM preserved'
    Assert ((Get-ADBMedicHash $requestPath) -ceq (Get-ADBMedicHash (Join-Path $rounds[0].FullName 'exports/evidence/request-source.txt'))) 'original imported evidence is retained only in validated round'
    $test.FailedJobs=$false

    $imported=Read-ADBMedicRequestFile $requestPath $caseId;$before=$test.Calls.Count
    Answers @();$blocked=$false
    try{Invoke-ADBMedicConfirmedFollowup $case.Directory $imported en|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'replay'}
    Assert ($blocked -and $test.Calls.Count -eq $before -and -not $test.Prompts.Count) 'replay rejected before confirmation or ADB enumeration'
    $modified=$text|ConvertFrom-Json;$modified.checks=@($modified.checks[1],$modified.checks[0])
    Assert ((Get-ADBMedicRequestFingerprint $modified) -ceq (Get-ADBMedicRequestFingerprint $imported.Request)) 'JSON order and whitespace cannot evade replay detection'
    $cpu=@{schema='adbmedic.followup.v1';case_id=$caseId;reason='TEST_CPU';checks=@(@{id='cpu_threads';target_pid=321})}|ConvertTo-Json -Depth 5|ConvertFrom-Json
    $hash=Get-ADBMedicRequestFingerprint $cpu;$cpu.checks[0]|Add-Member samples 3;$cpu.checks[0]|Add-Member interval_seconds 5
    Assert ((Get-ADBMedicRequestFingerprint $cpu) -ceq $hash) 'explicit default parameters are semantically the same request'
    $portable=$text|ConvertFrom-Json;$portable.reason="TEST <tag> & ' Unicode: π русский"
    $portablePath=Join-Path $stage 'canonical-request.json';Write-ADBMedicJson $portablePath $portable
    $harness=Join-Path $stage 'fingerprint-harness.ps1'
    [IO.File]::WriteAllText($harness,@'
param([string]$SourceRoot,[string]$RequestFile)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
. (Join-Path $SourceRoot 'ADBMedic-Handoff.ps1')
. (Join-Path $SourceRoot 'ADBMedic-Followup.ps1')
Get-ADBMedicRequestFingerprint (Read-ADBMedicControlJson $RequestFile)
'@,[Text.UTF8Encoding]::new($true))
    $ps51=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $childHash=@(& $ps51 -NoProfile -NonInteractive -File $harness -SourceRoot $root -RequestFile $portablePath)
    Assert ($LASTEXITCODE -eq 0 -and $childHash.Count -eq 1 -and $childHash[0] -ceq (Get-ADBMedicRequestFingerprint $portable)) 'fingerprint matches PS5 child across engines with HTML and Unicode'

    $paste=Request-Text $caseId 'TEST_SECOND_MEASUREMENT_PURPOSE'
    Answers (@('3','2','```json')+@($paste -split '\r?\n')+@('```','END','y','0'))
    $output=@(Show-ADBMedicCaseMenu $case.Directory $case.Bundle ru *>&1)
    Assert ($test.Answers.Count -eq 0 -and ($output -join "`n").Contains('Прикрепите этот НОВЫЙ ZIP в тот же чат ИИ.')) 'multiline fenced paste follows the same engine in Russian UI'
    $rounds=@(Get-ChildItem -LiteralPath (Join-Path $case.Directory 'followups') -Directory)
    Assert ($rounds.Count -eq 2 -and (Get-ADBMedicHash $originalZip) -ceq $originalHash) 'multiple rounds preserve baseline'
    Assert (@($rounds|Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'exports/manifest.json')}).Count -eq 2) 'both rounds remain available'

    foreach($value in @('{TEST_PRIVATE_REQUEST_DETAIL',($text.Replace($caseId,'TEST_WRONG_CASE')),($text.Replace('battery_timeline','TEST_UNKNOWN')),($text.Replace('"schema":','"command":"TEST_PRIVATE_REQUEST_DETAIL", "schema":')),($text.Replace('battery_timeline','reboot; TEST_COMMAND')))){
        Reject-Text $value $caseId
    }
    Reject-Text ([string]::new([char]'X',65537)) $caseId 'size'
    Reject-Text ('```json'+"`n"+$text) $caseId 'fence'
    Reject-Text ("Explanation`n"+$text) $caseId 'json'
    $badCpu=@{schema='adbmedic.followup.v1';case_id=$caseId;reason='TEST';checks=@(@{id='cpu_threads'})}|ConvertTo-Json -Depth 5
    $field='';try{Import-Text $badCpu $caseId|Out-Null}catch{$field=$_.Exception.Data['ADBMedicRequestField']}
    Assert ($field -ceq 'checks.target_pid') 'missing check parameter identified without exposing its value'
    $commentRequest=$text|ConvertFrom-Json;$commentRequest.reason='TEST literal ``` and $(TEST_DATA) are data'
    Assert ((Import-Text ($commentRequest|ConvertTo-Json -Depth 5) $caseId).Request.reason -ceq $commentRequest.reason) 'code-like reason text remains data and is never evaluated'
    $invalidPath=Join-Path $requests 'invalid.json';[IO.File]::WriteAllText($invalidPath,'TEST_PRIVATE_REQUEST_DETAIL')
    $test.PickerPath=$invalidPath;Answers @('3','1','0');$before=$test.Calls.Count
    $output=@(Show-ADBMedicCaseMenu $case.Directory $case.Bundle en *>&1)
    Assert ($test.Calls.Count -eq $before -and -not (($output -join '|').Contains('TEST_PRIVATE_REQUEST_DETAIL'))) 'invalid file error hides raw input and keeps menu alive'
    Assert (($output -join '|').Contains('Malformed JSON')) 'invalid JSON has helpful fixed error text'
    Answers @('CANCEL');Assert ($null -eq (Read-ADBMedicPastedRequest $caseId en)) 'paste cancellation'
    Answers @('END');Assert ($null -eq (Read-ADBMedicPastedRequest $caseId en)) 'empty paste cancellation'
    Answers (@($text -split '\r?\n')+@('END'));Assert ((Read-ADBMedicPastedRequest $caseId en).Request.case_id -ceq $caseId) 'unfenced multiline JSON accepted by the same parser'
    Answers @([string]::new([char]'X',65537));$blocked=$false
    try{Read-ADBMedicPastedRequest $caseId en|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'size'};Assert $blocked 'paste byte limit enforced without evaluation'
    $test.PickerStatus='cancelled';Answers @('1');Assert ($null -eq (Import-ADBMedicInteractiveRequest $caseId en)) 'picker cancellation does not request a path'
    $test.PickerStatus='unavailable';Answers @('1',('"'+$requestPath+'"'))
    Assert ((Import-ADBMedicInteractiveRequest $caseId en).Request.case_id -ceq $caseId) 'headless typed-path fallback accepts quoted spaced paths'
    $test.PickerStatus='selected';$test.PickerPath=$requestPath

    [IO.Directory]::CreateDirectory($test.Downloads)|Out-Null
    [IO.File]::Copy($requestPath,(Join-Path $test.Downloads 'followup-request.json'))
    [IO.File]::Copy($requestPath,(Join-Path $test.Downloads 'followup-request (1).json'))
    Answers @('');Assert ($null -eq (Select-ADBMedicDownloadedRequest en)) 'multiple Downloads candidates never silently selected'
    Answers @('2');Assert ((Select-ADBMedicDownloadedRequest en) -like '*.json') 'explicit Downloads choice'
    $test.Downloads=Join-Path $stage 'TEST absent Downloads';Assert ($null -eq (Select-ADBMedicDownloadedRequest en)) 'missing Downloads handled without a watcher'
    $tooLarge=Join-Path $requests 'large.json';[IO.File]::WriteAllBytes($tooLarge,(New-Object byte[] 65537))
    $blocked=$false;try{Read-ADBMedicRequestFile $tooLarge $caseId|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'size'};Assert $blocked 'file size bound enforced before parsing'
    $junction=Join-Path $stage 'TEST request junction'
    New-Item -ItemType Junction -Path $junction -Target $requests|Out-Null
    try{$blocked=$false;try{Read-ADBMedicRequestFile (Join-Path $junction 'followup-request.json') $caseId|Out-Null}catch{$blocked=$true};Assert $blocked 'request path through a reparse directory rejected'}finally{[IO.Directory]::Delete($junction)}

    $nextText=Request-Text $caseId 'TEST_CANCEL_OR_RECONNECT';$next=Import-Text $nextText $caseId
    Answers @('n');$before=$test.Calls.Count;Assert ($null -eq (Invoke-ADBMedicConfirmedFollowup $case.Directory $next en)) 'confirmation cancellation';Assert ($test.Calls.Count -eq $before) 'cancelled confirmation issues no ADB commands'
    $test.MissingAdb=$true;Answers @('y');$blocked=$false
    try{Invoke-ADBMedicConfirmedFollowup $case.Directory $next en|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'adb'}
    Assert ($blocked -and $test.Calls.Count -eq $before) 'missing ADB cannot execute a check';$test.MissingAdb=$false
    foreach($mode in @('unauthorized','disconnected')){
        $test.Device=$mode;Answers @('y','q');$before=$test.Calls.Count
        Assert ($null -eq (Invoke-ADBMedicConfirmedFollowup $case.Directory $next en)) 'reconnect may be cancelled'
        Assert ($test.Calls.Count -eq $before+1 -and $test.Calls[-1][0] -eq 'devices') 'unready phone never runs requested diagnostics'
    }
    $test.Device='wrong';Answers @('y');$before=$test.Calls.Count;$blocked=$false
    try{Invoke-ADBMedicConfirmedFollowup $case.Directory $next en|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'device'}
    Assert ($blocked -and $test.Calls.Count -eq $before+1) 'wrong device stops before requested checks'
    $test.Device='ready';$test.Build='TEST_DIFFERENT_BUILD';Answers @('y');$before=$test.Calls.Count;$blocked=$false
    try{Invoke-ADBMedicConfirmedFollowup $case.Directory $next en|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'build'}
    Assert ($blocked -and $test.Calls.Count -eq $before+2) 'changed build allows only enumeration and binding read'
    $test.Build='TEST_BUILD';Answers @('y');$bundle=Invoke-ADBMedicConfirmedFollowup $case.Directory $next en
    Assert $bundle.Ready 'binding failure can be retried after reconnect; no measurements had executed'
    $caseLock=[IO.File]::Open((Join-Path $case.Directory 'investigation.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{
        $r=(Request-Text $caseId 'TEST_CONCURRENT_WINDOW')|ConvertFrom-Json;$before=$test.Calls.Count;$blocked=$false
        try{Invoke-ADBMedicFollowupRound $case.Directory $r 'adb' 'TEST_SERIAL'|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'busy'}
        Assert ($blocked -and $test.Calls.Count -eq $before) 'concurrent case lock prevents ADB execution'
    }finally{$caseLock.Dispose()}

    $pendingText=Request-Text $caseId 'TEST_INTERRUPTED_REQUEST';$pending=Import-Text $pendingText $caseId
    $pendingPath=Join-Path $case.Directory ('followups/'+[guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($pendingPath)|Out-Null
    Write-ADBMedicJson (Join-Path $pendingPath 'case.json') @{schema='adbmedic.case.v1';case_id=$caseId;requestFingerprint=(Get-ADBMedicRequestFingerprint $pending.Request);requestFingerprintVersion=1;requestStatus='collecting'}
    $before=$test.Calls.Count;$blocked=$false;Answers @()
    try{Invoke-ADBMedicConfirmedFollowup $case.Directory $pending en|Out-Null}catch{$blocked=$_.Exception.Data['ADBMedicRequestCode'] -eq 'replay'}
    Assert ($blocked -and $test.Calls.Count -eq $before) 'interrupted attempt cannot replay after restart'
    $saved=@(Get-ADBMedicSavedCases $data|Where-Object Valid)
    Assert ($saved.Count -eq 1 -and $saved[0].Interrupted -and $saved[0].Bundle.ArchiveName -like 'ADBMedic-followup-*') 'resume selects latest valid ZIP while preserving interrupted evidence'
    Answers @('1','0');$before=$test.Calls.Count
    $output=@(& (Join-Path $root 'Start-ADBMedic.ps1') -Language en-US -SkipInstall *>&1)
    Assert ($test.Calls.Count -eq $before -and $test.Answers.Count -eq 0) 'real launcher resumes before any ADB initialization'
    Assert (($output -join '|').Contains('3. I have a new request') -and ($output -join '|').Contains('interrupted')) 'resumed launcher exposes same menu and interruption notice'

    $other=New-Case 'TEST other' '2000-01-02T00:00:00+03:00'
    Answers @('');$selected=Select-ADBMedicResumeCase $data en
    Assert ($selected.Case.State.case_id -ceq $other.State.case_id) 'newest valid case offered by default'
    Answers @('2','2');$selected=Select-ADBMedicResumeCase $data en
    Assert ($selected.Case.State.case_id -ceq $caseId) 'another case selectable without a path'
    $other.State.created=$case.State.created;Write-ADBMedicJson (Join-Path $other.Directory 'case.json') $other.State
    Answers @('','2');$selected=Select-ADBMedicResumeCase $data en
    Assert ($test.Prompts -contains 'Case number; Enter to cancel') 'equal timestamps require explicit case choice'
    Answers @('0');Assert ((Select-ADBMedicResumeCase $data en).Action -eq 'exit') 'startup exit preserves saved cases'
    $legacy=Join-Path $data 'session-TEST legacy';[IO.Directory]::CreateDirectory($legacy)|Out-Null
    Write-ADBMedicJson (Join-Path $legacy 'case.json') @{schema='adbmedic.case.v1';case_id=('CASE-'+('b'*32));created='2000-01-03T00:00:00Z'}
    Assert (@(Get-ADBMedicSavedCases $data|Where-Object {-not $_.Valid}).Count -eq 1) 'unbound legacy metadata is not resumable'
    $other.State|Add-Member interactiveVersion 2 -Force;Write-ADBMedicJson (Join-Path $other.Directory 'case.json') $other.State
    Assert (@(Get-ADBMedicSavedCases $data|Where-Object {-not $_.Valid}).Count -eq 2) 'incompatible future case version is rejected'
    $retry=Join-Path $data 'session-TEST interrupted packaging';[IO.Directory]::CreateDirectory($retry)|Out-Null
    $retryState=Get-ADBMedicCaseState $retry;$retryState.answerLocale='en-US';$retryState.target=$case.State.target
    Write-ADBMedicJson (Join-Path $retry 'case.json') $retryState
    [IO.File]::WriteAllText((Join-Path $retry 'symptom.txt'),'TEST_INTERRUPTED_PACKAGING')
    Assert (@(Get-ADBMedicSavedCases $data|Where-Object {$_.Valid -and $_.Directory -ceq $retry}).Count -eq 1) 'sufficient metadata can resume an unexported case'
    Answers @('4','0');Show-ADBMedicCaseMenu $retry $null en
    Assert (Test-Path -LiteralPath (Join-Path $retry 'exports/manifest.json')) 'packaging retry uses existing evidence without new diagnostics'
    Assert ((Get-ADBMedicHash $originalZip) -ceq $originalHash -and $test.Network -eq 0) 'all flows keep original archive and never upload'
    Write-Output ('Offline interactive tests: PASS ('+$test.Passed+' assertions).')
}finally{
    $env:LOCALAPPDATA=$savedLocalData
    $target=Assert-ADBMedicLocalDirectory $stage;$prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work'))+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe synthetic cleanup.'}
    [IO.Directory]::Delete($target,$true)
}
