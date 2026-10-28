$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'ADBMedic-Handoff.ps1')
$stage=Join-Path $root ('.test-work/handoff-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage)|Out-Null
$passed=0
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw ('Handoff test failed: '+$Message)};$script:passed++}
function New-Fixture([string]$Name){
    $session=Join-Path $stage $Name;[IO.Directory]::CreateDirectory($session)|Out-Null
    $data=[ordered]@{
        'symptom.txt'="TEST_SYNTHETIC_SYMPTOM`r`nUnchanged complaint"
        'profile.json'='{"model":"TEST_MODEL","android":"14"}'
        'model.txt'="TEST_MODEL`r`n";'android.txt'="14`n";'sdk.txt'="34`n";'build-fingerprint.txt'="TEST_SYNTHETIC_BUILD`n"
        'cpu.txt'="12% 321/TEST_PROCESS: 8% user`r`nPID 321 TID 322 UID 10123 com.example.synthetic"
        'top.txt'="PID TID USER %CPU ARGS`n321 322 10123 12 com.example.synthetic`n"
        'battery.txt'="Statistics since last charge:`n  Time on battery: 2h 0m 0s (100%) realtime`n  Estimated power use (mAh):`n    Computed drain: 10`n    Uid u0a123: 3`n  u0a123:`n    Wakeup alarm TEST_TAG: 4 times`n"
        'packages.txt'="package:com.example.synthetic uid:10123`n"
        'battery-state.txt'="  AC powered: false`n  USB powered: true`n  Wireless powered: false`n  level: 70`n  scale: 100`n"
        'power.txt'="mWakefulness=Awake`n";'uptime.txt'="3600.50 5000.00`n"
        'jobs.txt'='TEST_PERMISSION_DENIED'
    }
    $records=@()
    foreach($name in $data.Keys){
        [IO.File]::WriteAllText((Join-Path $session $name),$data[$name],[Text.UTF8Encoding]::new($true))
        if($name.EndsWith('.txt') -and $name -ne 'symptom.txt'){
            $records+=,[pscustomobject]@{id=$name.Replace('.txt','');file=$name;arguments=@('exec-out','TEST_DIAGNOSTIC');status=$(if($name -eq 'jobs.txt'){'failed'}else{'collected'});complete=$true;exitCode=$(if($name -eq 'jobs.txt'){13}else{0});startedUtc='2000-01-01T00:00:00Z';finishedUtc='2000-01-01T00:00:01Z'}
        }
    }
    Write-ADBMedicJson (Join-Path $session 'collection.json') $records
    # Deliberately unrelated app content is not a permitted evidence filename.
    [IO.File]::WriteAllText((Join-Path $session 'messages.txt'),'TEST_SYNTHETIC_CHAT_CONTENT')
    return $session
}
try{
    foreach($locale in @('ru-RU','en-US','fr-FR','zh-CN')){
        $session=New-Fixture ('TEST путь с пробелами '+$locale)
        # Binary/invalid UTF-8 and a secret-like string must survive private packaging.
        [IO.File]::WriteAllBytes((Join-Path $session 'camera.txt'),[byte[]]@(0,255,254,13,10,239,187,191))
        [IO.File]::WriteAllText((Join-Path $session 'sensors.txt'),('gh'+'p_'+('X'*36)))
        $bundle=& (Join-Path $root 'Package-ADBMedic.ps1') -Session $session -Language $locale -PassThru
        Assert ($bundle.Ready -and $bundle.SchemaVersion -eq 3) 'v3 bundle is ready'
        $manifest=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'manifest.json')
        $facts=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'facts.json')
        $conditions=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'conditions.json')
        Assert ($manifest.case_id -ceq $bundle.CaseId -and $manifest.answerLanguage -ceq $locale) 'identity and full language are explicit'
        Assert ($facts.language -ceq $locale -and $facts.schemaVersion -eq 3) 'facts preserve full locale'
        Assert ($conditions.idleDischarge.availability -ceq 'unknown') 'charging snapshot cannot establish idle discharge'
        Assert (($conditions.observations|Where-Object name -eq usbPowered).value -eq $true) 'USB condition has honest parsed value'
        Assert (($conditions.observations|Where-Object name -eq batteryPercent).value -eq 70) 'battery percent needs explicit scale'
        Assert (($manifest.commands|Where-Object file -eq evidence/jobs.txt).status -ceq 'failed') 'permission failure is retained'
        Assert (($manifest.commands|Where-Object file -eq evidence/thermal.txt).status -ceq 'missing') 'missing measurement is not zero'
        Assert ($facts.analysis.energySections[0].entries[0].measurementKind -ceq 'estimated') 'modeled energy is explicitly estimated'
        Assert ($facts.analysis.counters[0].units.count -ceq 'events') 'typed counter has units and provenance'
        foreach($name in @('INVESTIGATE.md','agent/investigation-rules.md','agent/check-catalog.json','agent/followup-request.example.json','device.json','conditions.json','START-PROMPT.txt','REPORT.md','REPORT.html','SUMMARY.md')){Assert (Test-Path -LiteralPath (Join-Path $bundle.Directory $name)) 'self-contained investigation documents exist'}
        Assert ($bundle.StarterPrompt.Contains('INVESTIGATE.md') -and $bundle.StarterPrompt.Contains($locale)) 'starter routes to investigator in case language'
        Assert (-not (Test-Path -LiteralPath (Join-Path $bundle.Directory 'evidence/messages.txt'))) 'unrequested app contents are not exported'
        foreach($name in @('camera.txt','battery.txt','cpu.txt','sensors.txt','symptom.txt')){Assert ((Get-ADBMedicHash (Join-Path $session $name)) -ceq (Get-ADBMedicHash (Join-Path $bundle.Directory ('evidence/'+$name)))) 'original bytes including BOM are preserved'}
        Assert ((Get-ADBMedicHash (Join-Path $session 'symptom.txt')) -ceq (Get-ADBMedicHash (Join-Path $bundle.Directory 'symptom.txt'))) 'root complaint is byte-identical'
        $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $bundle.Directory $bundle.ArchiveName))
        try{
            Assert ($zip.Entries.Count -eq $manifest.files.Count+1) 'manifest covers all members except itself'
            foreach($file in $manifest.files){
                $entry=$zip.GetEntry($file.file);Assert ($null -ne $entry -and $entry.Length -eq $file.bytes) 'manifest size matches ZIP entry'
                $stream=$entry.Open();$hash=[Security.Cryptography.SHA256]::Create()
                try{$actual=([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose();$stream.Dispose()}
                Assert ($actual -ceq $file.sha256) 're-read ZIP hash matches manifest'
            }
        }finally{$zip.Dispose()}
        $blocked=$false;try{New-ADBMedicDiagnosticBundle $session en|Out-Null}catch{$blocked=$true};Assert $blocked 'existing export is never overwritten'
    }
    $session=New-Fixture 'large-binary'
    $stream=[IO.File]::Create((Join-Path $session 'camera.txt'))
    try{$block=New-Object byte[] 65536;for($i=0;$i -lt 1025;$i++){$stream.Write($block,0,$block.Length)}}finally{$stream.Dispose()}
    $bundle=New-ADBMedicDiagnosticBundle $session en
    Assert ((Get-Item -LiteralPath (Join-Path $bundle.Directory 'evidence/camera.txt')).Length -gt 67108864) 'over-64-MiB binary evidence survives without size gate'
    Assert ((Get-ADBMedicHash (Join-Path $session 'camera.txt')) -ceq (Get-ADBMedicHash (Join-Path $bundle.Directory 'evidence/camera.txt'))) 'large evidence is byte-identical'
    $session=New-Fixture 'failed-valid-looking-battery'
    $records=Read-ADBMedicControlJson (Join-Path $session 'collection.json');($records|Where-Object file -eq battery.txt).status='failed'
    Write-ADBMedicJson (Join-Path $session 'collection.json') $records
    $bundle=New-ADBMedicDiagnosticBundle $session en
    $facts=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'facts.json')
    Assert ($facts.analysis.status -eq 'unsupported') 'failed partial body is not promoted into parsed facts'
    $session=New-Fixture 'malformed-collection'
    [IO.File]::WriteAllText((Join-Path $session 'collection.json'),'TEST_INVALID_JSON')
    $bundle=New-ADBMedicDiagnosticBundle $session en
    $manifest=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'manifest.json')
    Assert ($manifest.metadataIssues -contains 'collection-metadata-unreadable') 'broken metadata does not discard original evidence'
    $session=Join-Path $stage 'all-failed';[IO.Directory]::CreateDirectory($session)|Out-Null
    Write-ADBMedicJson (Join-Path $session 'collection.json') @([pscustomobject]@{file='cpu.txt';status='failed';exitCode=1;complete=$false})
    $bundle=New-ADBMedicDiagnosticBundle $session en
    Assert $bundle.Ready 'failure-only dossier still packages command outcomes'
    $session=New-Fixture 'oversize-analysis-line'
    [IO.File]::AppendAllText((Join-Path $session 'battery.txt'),([string]::new([char]'Z',70000)+"`n"))
    $bundle=New-ADBMedicDiagnosticBundle $session en
    $facts=Read-ADBMedicControlJson (Join-Path $bundle.Directory 'facts.json')
    Assert ($facts.analysis.issues.code -contains 'oversize-battery-lines-not-parsed') 'bounded derived reader discloses skipped huge lines'
    Assert ((Get-ADBMedicHash (Join-Path $session 'battery.txt')) -ceq (Get-ADBMedicHash (Join-Path $bundle.Directory 'evidence/battery.txt'))) 'parser limits do not change raw bytes'
    Write-Output ('Offline handoff tests: PASS ('+$passed+' assertions).')
}finally{
    $target=Assert-ADBMedicLocalDirectory $stage
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work'))+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe cleanup.'}
    [IO.Directory]::Delete($target,$true)
}
