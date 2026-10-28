$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'ADBMedic-Handoff.ps1')
. (Join-Path $root 'ADBMedic-Followup.ps1')
$stage=Join-Path $root ('.test-work/investigation-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage)|Out-Null
$passed=0;$transportCalls=@()
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw ('Investigation test failed: '+$Message)};$script:passed++}
function Request([string]$Id='camera_clients'){
    return [pscustomobject]@{schema='adbmedic.followup.v1';case_id=$caseId;reason='TEST_DIFFERENTIAL';checks=@([pscustomobject]@{id=$Id})}
}
function Expect-Rejected($Object){$blocked=$false;try{ConvertTo-ADBMedicFollowupPlan $Object $caseId|Out-Null}catch{$blocked=$true};Assert $blocked 'invalid request is rejected before execution'}
function synthetic-adb {
    $script:transportCalls+=,@($args);$global:LASTEXITCODE=0
    if($args -contains 'getprop'){return 'TEST_BUILD'}
    if($args -contains 'media.camera'){$global:LASTEXITCODE=13;return 'TEST_PERMISSION_DENIED'}
    if($args -contains 'battery'){return "  USB powered: true`n  level: 75`n  scale: 100"}
    return '321 (TEST_PROCESS) TEST_SYNTHETIC_DATA'
}
try{
    # Exercise the real native byte transport without ADB or a device.
    $engine=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'})
    $child=@'
$ProgressPreference='SilentlyContinue';$out=[Console]::OpenStandardOutput();$err=[Console]::OpenStandardError()
$block=New-Object byte[] 65536;for($i=0;$i -lt $block.Length;$i++){$block[$i]=[byte]($i%256)}
for($i=0;$i -lt 8;$i++){$out.Write($block,0,$block.Length);$err.Write($block,0,$block.Length)}
$out.Flush();$err.Flush();exit 7
'@
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))
    $record=Invoke-ADBMedicCapture $engine @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded) $stage 'native.txt' 30 'synthetic-native'
    Assert ($record.exitCode -eq 7 -and $record.status -eq 'failed' -and $record.complete) 'nonzero native command retains complete stdout/stderr'
    Assert ($record.fidelity -ceq 'native-bytes') 'native path promises byte fidelity'
    Assert ((Get-Item -LiteralPath (Join-Path $stage 'native.txt')).Length -eq 524288) 'large pipe output is not lost or deadlocked'
    Assert ((Get-ADBMedicHash (Join-Path $stage 'native.txt')) -ceq (Get-ADBMedicHash (Join-Path $stage 'native.stderr.txt'))) 'separate stdout/stderr preserve binary byte patterns'
    $bytes=[IO.File]::ReadAllBytes((Join-Path $stage 'native.txt'))
    for($i=0;$i -lt 256;$i++){Assert ($bytes[$i] -eq $i) 'binary values are not decoded or normalized'}
    $child='[Console]::OpenStandardOutput().WriteByte(65); Start-Sleep -Seconds 15'
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $record=Invoke-ADBMedicCapture $engine @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded) $stage 'timeout.txt' 2 'synthetic-timeout'
    Assert ($record.status -ceq 'timeout' -and -not $record.complete -and $watch.Elapsed.TotalSeconds -lt 12) 'timeout is bounded and partial data is explicit'
    Assert ((Get-Item -LiteralPath (Join-Path $stage 'timeout.txt')).Length -eq 1) 'partial bytes are retained on timeout'
    $blocked=$false;try{Invoke-ADBMedicCapture $engine @() $stage 'native.txt'|Out-Null}catch{$blocked=$true};Assert $blocked 'native capture never overwrites files'

    $session=Join-Path $stage 'TEST case with spaces';[IO.Directory]::CreateDirectory($session)|Out-Null
    $state=Get-ADBMedicCaseState $session;$caseId=$state.case_id
    $fingerprint=Invoke-ADBMedicCapture 'synthetic-adb' @('-s','TEST_SERIAL','exec-out','getprop','ro.build.fingerprint') $session 'build-fingerprint.txt' 5 'device-binding'
    $state.target=[pscustomobject]@{adbSerial='TEST_SERIAL';fingerprintSha256=(Get-ADBMedicHash (Join-Path $session 'build-fingerprint.txt'))};$state.answerLocale='fr-FR'
    Write-ADBMedicJson (Join-Path $session 'case.json') $state
    [IO.File]::WriteAllText((Join-Path $session 'symptom.txt'),'TEST_ORIGINAL_COMPLAINT')
    foreach($id in @('camera_clients','sensor_clients','jobs_alarms','battery_timeline','power_sleep_state','gnss_activity','radio_network_state','thermal_history')){
        $plan=ConvertTo-ADBMedicFollowupPlan (Request $id) $caseId
        Assert ($plan.Count -eq 1 -and $plan[0].supported -and $plan[0].commands.Count -gt 0) 'known check maps to fixed commands'
    }
    foreach($id in @('cpu_threads','process_cpu_times','targeted_logcat','native_stack')){
        $r=Request $id;$r.checks[0]|Add-Member target_pid 321
        $plan=ConvertTo-ADBMedicFollowupPlan $r $caseId
        Assert ($plan[0].supported -eq ($id -ne 'native_stack')) 'privileged native stack is explicitly unavailable'
    }
    $r=Request 'wakelock_delta';$plan=ConvertTo-ADBMedicFollowupPlan $r $caseId
    Assert ($plan[0].repeat -eq 2) 'wake-lock delta captures two originals without reset'
    foreach($id in @('TEST_UNKNOWN','camera_clients; reboot','CAMERA_CLIENTS')){Expect-Rejected (Request $id)}
    foreach($value in @('321; reboot',0,-1,4194305,$true,3.5)){$r=Request 'cpu_threads';$r.checks[0]|Add-Member target_pid $value;Expect-Rejected $r}
    foreach($value in @(0,13,'3',3.5)){$r=Request 'cpu_threads';$r.checks[0]|Add-Member target_pid 321;$r.checks[0]|Add-Member samples $value;Expect-Rejected $r}
    foreach($value in @(0,61,'5')){$r=Request 'cpu_threads';$r.checks[0]|Add-Member target_pid 321;$r.checks[0]|Add-Member interval_seconds $value;Expect-Rejected $r}
    $r=Request;$r|Add-Member command 'TEST_COMMAND';Expect-Rejected $r
    $r=Request;$r.checks[0]|Add-Member arguments @('TEST_ARGUMENT');Expect-Rejected $r
    $r=Request;$r.checks[0]|Add-Member target_pid 321;Expect-Rejected $r
    $r=Request;$r.case_id='TEST_WRONG_CASE';Expect-Rejected $r
    $r=Request;$r.checks=@();Expect-Rejected $r
    $r=Request;$r.checks=@($r.checks[0],$r.checks[0]);Expect-Rejected $r
    $r=Request;$r.checks=@(1,2,3,4);Expect-Rejected $r
    $r=Request 'wakelock_delta';$r.checks[0]|Add-Member samples 3;Expect-Rejected $r
    $r=Request 'cpu_threads';$r.checks[0]|Add-Member target_pid 321;$r.checks[0]|Add-Member samples 12;$r.checks[0]|Add-Member interval_seconds 60
    $plan=ConvertTo-ADBMedicFollowupPlan $r $caseId
    Assert ($plan[0].commands[0][4] -ceq '12') 'validated numeric sampling becomes fixed argv'
    $callsBefore=$transportCalls.Count
    $blocked=$false;try{Invoke-ADBMedicFollowupRound $session (Request) 'synthetic-adb' 'TEST_OTHER_DEVICE'|Out-Null}catch{$blocked=$true}
    Assert ($blocked -and $transportCalls.Count -eq $callsBefore) 'wrong device rejected before any ADB check'
    $bundle=Invoke-ADBMedicFollowupRound $session (Request) 'synthetic-adb' 'TEST_SERIAL'
    $manifest=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'manifest.json')
    Assert ($bundle.Ready -and $bundle.CaseId -ceq $caseId -and $manifest.parent_case_id -ceq $caseId -and $manifest.round_id) 'follow-up has same case and unique round'
    Assert ($manifest.answerLanguage -ceq 'fr-FR') 'follow-up retains baseline answer language'
    Assert (@($manifest.commands|Where-Object {$_.id -eq 'camera_clients' -and $_.status -eq 'failed'}).Count -eq 2) 'permission-denied stdout/stderr outcome is explicit'
    Assert (Test-Path -LiteralPath (Join-Path $bundle.Directory 'evidence/request.json')) 'requested checks are included for reconciliation'
    Assert ([IO.File]::ReadAllText((Join-Path $bundle.Directory 'symptom.txt')) -ceq 'TEST_ORIGINAL_COMPLAINT') 'original complaint survives the follow-up round'
    $r=Request 'native_stack';$r.checks[0]|Add-Member target_pid 321
    $unsupportedBundle=Invoke-ADBMedicFollowupRound $session $r 'synthetic-adb' 'TEST_SERIAL'
    $unsupportedManifest=Read-ADBMedicControlJson (Join-Path $unsupportedBundle.Directory 'manifest.json')
    Assert (($unsupportedManifest.commands|Where-Object id -eq native_stack).status -eq 'unsupported') 'unavailable check stays unsupported when no output file exists'
    Assert ($unsupportedBundle.Directory -cne $bundle.Directory -and (Test-Path -LiteralPath (Join-Path $bundle.Directory $bundle.ArchiveName))) 'additional rounds preserve previous ZIPs'
    foreach($call in $transportCalls){Assert (@($call|Where-Object {$_ -in @('root','reboot','kill','clear','reset','install','uninstall','setprop')}).Count -eq 0) 'only read-only command arguments are emitted'}
    $state.target.fingerprintSha256='TEST_OTHER_BUILD';Write-ADBMedicJson (Join-Path $session 'case.json') $state
    $callsBefore=$transportCalls.Count;$blocked=$false
    $changedRequest=Request;$changedRequest.reason='TEST_NEW_BUILD_CHECK'
    try{Invoke-ADBMedicFollowupRound $session $changedRequest 'synthetic-adb' 'TEST_SERIAL'|Out-Null}catch{$blocked=$true}
    Assert ($blocked -and $transportCalls.Count -eq $callsBefore+1) 'build mismatch stops before requested checks'
    $skill=[IO.File]::ReadAllText((Join-Path $root '.agents/skills/android-investigator/SKILL.md'))
    Assert ($skill -match '(?s)^---\r?\nname: android-investigator\r?\ndescription: [^\r\n]+\r?\n---\r?\n') 'optional skill has valid required scalar frontmatter'
    $catalog=Read-ADBMedicControlJson (Join-Path $root 'agent/check-catalog.json')
    Assert ($catalog.checks.Count -eq 13 -and @($catalog.checks|Where-Object available -eq $false).Count -eq 1) 'catalog distinguishes implemented checks from unavailable native attachment'
    # A generated private metadata file remains forbidden even if someone edits the source manifest.
    . (Join-Path $root 'scripts/Privacy.Core.ps1')
    foreach($name in @('manifest.json','conditions.json','facts.json','collection.json','case.json','request.json','followup-request.json','followup-results.json','device.json','cpu.stderr.txt','evidence/test.txt','followups/test.txt')){Assert (Test-PrivacyForbiddenPath $name) 'generated case paths cannot enter a source manifest'}
    Write-Output ('Offline investigation tests: PASS ('+$passed+' assertions).')
}finally{
    $target=Assert-ADBMedicLocalDirectory $stage
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work'))+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe cleanup.'}
    [IO.Directory]::Delete($target,$true)
}
