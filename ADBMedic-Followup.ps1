# Closed diagnostic request protocol. Model text is never a command line.
function Assert-ADBMedicObjectKeys {
    param($Object,[string[]]$Allowed,[string[]]$Required=@(),[string]$Context='request')
    if($null -eq $Object -or $Object -isnot [pscustomobject]){Stop-ADBMedicRequest 'validation' $Context}
    foreach($key in $Object.PSObject.Properties.Name){if($Allowed -cnotcontains $key){Stop-ADBMedicRequest 'validation' $(if($Context -eq 'checks'){'checks.fields'}else{'fields'})}}
    foreach($key in $Required){if($Object.PSObject.Properties.Name -cnotcontains $key){Stop-ADBMedicRequest 'validation' $(if($Context -eq 'checks'){'checks.'+$key}else{$key})}}
}

function Get-ADBMedicRequestInteger {
    param($Value,[int]$Minimum,[int]$Maximum,[string]$Field='checks.parameters')
    if(($Value -isnot [int] -and $Value -isnot [long]) -or $Value -lt $Minimum -or $Value -gt $Maximum){Stop-ADBMedicRequest 'validation' $Field}
    return [int]$Value
}

function Stop-ADBMedicRequest {
    param([string]$Code,[string]$Field='request')
    $errorObject=New-Object IO.InvalidDataException('Follow-up request rejected.')
    $errorObject.Data['ADBMedicRequestCode']=$Code
    $errorObject.Data['ADBMedicRequestField']=$Field
    throw $errorObject
}

function ConvertFrom-ADBMedicRequestBytes {
    param([byte[]]$Bytes,[string]$CaseId)
    if(-not $Bytes.Length -or $Bytes.Length -gt 65536){Stop-ADBMedicRequest 'size' 'request'}
    try{$original=([Text.UTF8Encoding]::new($false,$true)).GetString($Bytes).TrimStart([char]0xFEFF)}catch{Stop-ADBMedicRequest 'encoding' 'request'}
    $json=$original.Trim()
    if($json.StartsWith('```')){
        if($json -notmatch '(?s)^```(?:json)?\s*\r?\n(?<body>.*?)\r?\n```$'){Stop-ADBMedicRequest 'fence' 'request'}
        $json=$Matches.body
    }elseif($json.EndsWith('```')){Stop-ADBMedicRequest 'fence' 'request'}
    try{$request=ConvertFrom-Json -InputObject $json -ErrorAction Stop}catch{Stop-ADBMedicRequest 'json' 'request'}
    try{$plan=ConvertTo-ADBMedicFollowupPlan $request $CaseId}catch{
        if($_.Exception.Data['ADBMedicRequestCode']){throw}
        # Only fixed public field names are exposed; parser errors and values remain private.
        $message=$_.Exception.Message
        $field=if($message -like '*reason*'){'reason'}elseif($message -like '*integer*' -or $message -like '*parameter*'){'checks.parameters'}elseif($message -like '*check*' -or $message -like '*Delta*'){'checks'}else{'schema / fields'}
        Stop-ADBMedicRequest 'validation' $field
    }
    $catalog=Read-ADBMedicControlJson (Join-Path $PSScriptRoot 'agent/check-catalog.json')
    foreach($check in $plan){
        $known=@($catalog.checks|Where-Object id -CEQ $check.id)
        if($known.Count -ne 1 -or -not $known[0].available){Stop-ADBMedicRequest 'unsupported' 'checks.id'}
    }
    $jsonBytes=if($json -ceq $original.Trim() -and -not $original.Trim().StartsWith('```')){$Bytes}else{[Text.UTF8Encoding]::new($false).GetBytes($json)}
    return [pscustomobject]@{Request=$request;Plan=$plan;Bytes=$jsonBytes;OriginalBytes=$Bytes}
}

function Get-ADBMedicRequestFingerprint {
    param($Request)
    $plan=ConvertTo-ADBMedicFollowupPlan $Request $Request.case_id
    $checks=@(foreach($check in @($plan|Sort-Object id)){
        [ordered]@{id=$check.id;commands=$check.commands;repeat=$check.repeat;intervalSeconds=$check.intervalSeconds}
    })
    $normalized=[ordered]@{schema=$Request.schema;case_id=$Request.case_id;reason=$Request.reason.Trim();checks=$checks}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $normalized -Depth 8 -Compress))
    $hash=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
}

function Assert-ADBMedicRequestNotReplayed {
    param([string]$Session,[string]$CaseId,[string]$Fingerprint)
    $parent=Join-Path $Session 'followups'
    if(-not (Test-Path -LiteralPath $parent)){return}
    $parent=Assert-ADBMedicLocalDirectory $parent
    foreach($directory in Get-ChildItem -LiteralPath $parent -Directory -Force){
        if($directory.Name -cnotmatch '^[a-f0-9]{32}$'){continue}
        $roundPath=Assert-ADBMedicLocalDirectory $directory.FullName
        $statePath=Join-Path $roundPath 'case.json'
        if(-not (Test-Path -LiteralPath $statePath)){Stop-ADBMedicRequest 'history' 'case'}
        $state=Read-ADBMedicControlJson $statePath
        if($state.case_id -cne $CaseId){Stop-ADBMedicRequest 'history' 'case'}
        $old=$state.requestFingerprint
        if(-not $old -and (Test-Path -LiteralPath (Join-Path $roundPath 'request.json'))){
            $legacy=Read-ADBMedicControlJson (Join-Path $roundPath 'request.json')
            [void](ConvertTo-ADBMedicFollowupPlan $legacy $CaseId)
            $old=Get-ADBMedicRequestFingerprint $legacy
        }
        if($old -ceq $Fingerprint -and $state.requestStatus -cne 'binding-failed'){Stop-ADBMedicRequest 'replay' 'request'}
    }
}

function ConvertTo-ADBMedicFollowupPlan {
    param($Request,[string]$CaseId)
    Assert-ADBMedicObjectKeys $Request @('schema','case_id','reason','checks') @('schema','case_id','reason','checks')
    if($Request.schema -isnot [string] -or $Request.schema -cne 'adbmedic.followup.v1'){Stop-ADBMedicRequest 'schema' 'schema'}
    if($Request.case_id -isnot [string] -or $Request.case_id -cne $CaseId -or $CaseId -cnotmatch '^CASE-[a-f0-9]{32}$'){Stop-ADBMedicRequest 'case' 'case_id'}
    if($Request.reason -isnot [string] -or -not $Request.reason.Trim() -or $Request.reason.Length -gt 4096){throw 'Invalid request reason.'}
    if($Request.checks -isnot [array] -or $Request.checks.Count -lt 1 -or $Request.checks.Count -gt 3){throw 'Request must select 1 to 3 checks.'}
    $plan=@();$seen=@{};$estimatedSeconds=0
    foreach($check in $Request.checks){
        Assert-ADBMedicObjectKeys $check @('id','target_pid','samples','interval_seconds') @('id') -Context checks
        if($check.id -isnot [string] -or $seen.ContainsKey($check.id)){throw 'Invalid or duplicate check.'}
        $seen[$check.id]=$true;$pidValue=$null;$samples=1;$interval=1
        $permitted=@('id')
        if($check.id -cin @('cpu_threads','process_cpu_times','targeted_logcat','native_stack')){
            $pidValue=Get-ADBMedicRequestInteger $check.target_pid 1 4194304 'checks.target_pid';$permitted+='target_pid'
        }
        if($check.id -cin @('cpu_threads','process_cpu_times','wakelock_delta')){
            $permitted+=@('samples','interval_seconds')
            $samples=if($check.id -eq 'wakelock_delta'){2}else{3};$interval=5
            if($check.PSObject.Properties.Name -ccontains 'samples'){$samples=Get-ADBMedicRequestInteger $check.samples 1 12 'checks.samples'}
            if($check.PSObject.Properties.Name -ccontains 'interval_seconds'){$interval=Get-ADBMedicRequestInteger $check.interval_seconds 1 60 'checks.interval_seconds'}
            if($check.id -eq 'wakelock_delta' -and $samples -ne 2){throw 'Delta checks require exactly two snapshots.'}
        }
        Assert-ADBMedicObjectKeys $check $permitted @('id') -Context checks
        $commands=@();$supported=$true;$note=$null
        switch -CaseSensitive ($check.id){
            'cpu_threads' {$commands+=,@('top','-H','-b','-n',([string]$samples),'-d',([string]$interval),'-p',([string]$pidValue))}
            'process_cpu_times' {$commands+=,@('cat',('/proc/'+$pidValue+'/stat'));$note='PID identity may change; compare task names and starttime before comparing CPU ticks.'}
            'camera_clients' {$commands+=,@('dumpsys','media.camera')}
            'sensor_clients' {$commands+=,@('dumpsys','sensorservice')}
            'wakelock_delta' {$commands+=,@('dumpsys','batterystats');$note='Two cumulative snapshots, not an automatically computed delta. USB remains connected; not an idle discharge test.'}
            'jobs_alarms' {$commands+=,@('dumpsys','alarm');$commands+=,@('dumpsys','jobscheduler')}
            'battery_timeline' {$commands+=,@('dumpsys','batterystats','--history')}
            'power_sleep_state' {$commands+=,@('dumpsys','power');$commands+=,@('dumpsys','deviceidle')}
            'gnss_activity' {$commands+=,@('dumpsys','location');$note='May contain precise location; manually share only with a trusted investigator.'}
            'radio_network_state' {$commands+=,@('dumpsys','telephony.registry');$commands+=,@('dumpsys','connectivity');$commands+=,@('dumpsys','wifi');$commands+=,@('dumpsys','netstats')}
            'thermal_history' {$commands+=,@('dumpsys','thermalservice');$note='Service-reported history only when present; a current temperature is not a thermal history.'}
            'targeted_logcat' {$commands+=,@('logcat','-b','system','-b','crash','-d','-v','threadtime','--pid',([string]$pidValue),'-t','200');$note='Intentional last-200-record measurement, not silent file truncation. System/crash logs may incidentally contain sensitive content.'}
            'native_stack' {$supported=$false;$note='Not implemented: attaching to native processes can require privileges and disturb execution. No root or debugger is started.'}
            default {Stop-ADBMedicRequest 'unknown-check' 'checks.id'}
        }
        $repeat=if($check.id -in @('process_cpu_times','wakelock_delta')){$samples}else{1}
        $estimatedSeconds+=($samples*$interval)+($repeat*($commands.Count*120+30))
        $plan+=,[pscustomobject]@{id=$check.id;commands=$commands;repeat=$repeat;intervalSeconds=$interval;supported=$supported;note=$note}
    }
    if($estimatedSeconds -gt 1800){throw 'Request exceeds the bounded execution budget; split it into smaller rounds.'}
    return ,$plan
}

function Invoke-ADBMedicFollowupRound {
    param([string]$Session,$Request,[string]$Adb,[string]$Serial,[byte[]]$RequestBytes,[byte[]]$OriginalRequestBytes)
    $Session=Assert-ADBMedicLocalDirectory $Session
    $state=Get-ADBMedicCaseState $Session
    if($RequestBytes){$imported=ConvertFrom-ADBMedicRequestBytes $RequestBytes $state.case_id;$Request=$imported.Request}
    $plan=ConvertTo-ADBMedicFollowupPlan $Request $state.case_id
    if(-not $state.target -or $state.target.adbSerial -cne $Serial -or -not $state.target.fingerprintSha256){Stop-ADBMedicRequest 'device' 'case'}
    if($OriginalRequestBytes){
        $originalImport=ConvertFrom-ADBMedicRequestBytes $OriginalRequestBytes $state.case_id
        if((Get-ADBMedicRequestFingerprint $originalImport.Request) -cne (Get-ADBMedicRequestFingerprint $Request)){Stop-ADBMedicRequest 'validation' 'request'}
    }
    $fingerprint=Get-ADBMedicRequestFingerprint $Request
    $caseLock=$null
    try{
    try{$caseLock=[IO.File]::Open((Join-Path $Session 'investigation.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{Stop-ADBMedicRequest 'busy' 'case'}
    Assert-ADBMedicRequestNotReplayed $Session $state.case_id $fingerprint
    $roundId=[guid]::NewGuid().ToString('N')
    $parent=Join-Path $Session 'followups'
    if(-not (Test-Path -LiteralPath $parent)){[IO.Directory]::CreateDirectory($parent)|Out-Null}
    $parent=Assert-ADBMedicLocalDirectory $parent
    $directory=Join-Path $parent $roundId
    [IO.Directory]::CreateDirectory($directory)|Out-Null
    $round=[pscustomobject]@{schema='adbmedic.case.v1';case_id=$state.case_id;created=[DateTimeOffset]::Now.ToString('o');round_id=$roundId;parent_case_id=$state.case_id;target=$state.target;answerLocale=$state.answerLocale;requestFingerprint=$fingerprint;requestStatus='binding'}
    $baselineManifest=Join-Path $Session 'exports/manifest.json'
    $round|Add-Member -NotePropertyName baselineManifestSha256 -NotePropertyValue $(if(Test-Path -LiteralPath $baselineManifest -PathType Leaf){Get-ADBMedicHash $baselineManifest}else{$null})
    Write-ADBMedicJson (Join-Path $directory 'case.json') $round
    $records=New-Object 'System.Collections.Generic.List[object]'
    $fingerprint=Invoke-ADBMedicCapture $Adb @('-s',$Serial,'exec-out','getprop','ro.build.fingerprint') $directory 'build-fingerprint.txt' 30 'device-binding'
    $records.Add($fingerprint)
    Write-ADBMedicJson (Join-Path $directory 'collection.json') @($records.ToArray())
    if($fingerprint.status -ne 'collected' -or (Get-ADBMedicHash (Join-Path $directory 'build-fingerprint.txt')) -cne $state.target.fingerprintSha256){$round.requestStatus='binding-failed';Write-ADBMedicJson (Join-Path $directory 'case.json') $round;Stop-ADBMedicRequest 'build' 'case'}
    $round.requestStatus='collecting';Write-ADBMedicJson (Join-Path $directory 'case.json') $round
    # Preserve the exact request separately from executable plans; no model strings are evaluated.
    if($RequestBytes){[IO.File]::WriteAllBytes((Join-Path $directory 'request.json'),$RequestBytes)}else{Write-ADBMedicJson (Join-Path $directory 'request.json') $Request}
    if($OriginalRequestBytes){[IO.File]::WriteAllBytes((Join-Path $directory 'request-source.txt'),$OriginalRequestBytes)}
    if(Test-Path -LiteralPath (Join-Path $Session 'symptom.txt')){Copy-ADBMedicEvidenceFile (Join-Path $Session 'symptom.txt') (Join-Path $directory 'symptom.txt')}
    else{[IO.File]::WriteAllText((Join-Path $directory 'symptom.txt'),[string]$Request.reason,[Text.UTF8Encoding]::new($false))}
    foreach($check in $plan){
        if(-not $check.supported){
            $records.Add([pscustomobject]@{id=$check.id;file=($check.id.Replace('_','-')+'.txt');status='unsupported';complete=$false;error=$check.note;arguments=@()})
            Write-ADBMedicJson (Join-Path $directory 'collection.json') @($records.ToArray());continue
        }
        for($sample=1;$sample -le $check.repeat;$sample++){
            $index=0
            foreach($command in $check.commands){
                $index++;$name=$check.id.Replace('_','-')+'-'+$sample+'-'+$index+'.txt'
                $timeout=if($check.id -eq 'cpu_threads'){[Math]::Max(120,($check.commands[0][4] -as [int])*($check.intervalSeconds)+30)}else{120}
                $record=Invoke-ADBMedicCapture $Adb (@('-s',$Serial,'exec-out')+@($command)) $directory $name $timeout $check.id
                $records.Add($record)
                Write-ADBMedicJson (Join-Path $directory 'collection.json') @($records.ToArray())
            }
            # Record power state for each sample; no phone setting is changed.
            $name=$check.id.Replace('_','-')+'-'+$sample+'-conditions.txt'
            $records.Add((Invoke-ADBMedicCapture $Adb @('-s',$Serial,'exec-out','dumpsys','battery') $directory $name 30 'sample-conditions'))
            Write-ADBMedicJson (Join-Path $directory 'collection.json') @($records.ToArray())
            if($sample -lt $check.repeat){Start-Sleep -Seconds $check.intervalSeconds}
        }
    }
    Write-ADBMedicJson (Join-Path $directory 'followup-results.json') @($plan|Select-Object id,supported,note,repeat,intervalSeconds)
    $locale=if($state.answerLocale){$state.answerLocale}else{'en-US'}
    $bundle=New-ADBMedicDiagnosticBundle $directory $(if($locale -like 'ru*'){'ru'}else{'en'}) -AnswerLocale $locale
    $round.requestStatus='completed';Write-ADBMedicJson (Join-Path $directory 'case.json') $round
    return $bundle
    }finally{if($caseLock){$caseLock.Dispose()}}
}
