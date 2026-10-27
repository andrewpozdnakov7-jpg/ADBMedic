$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'ADBMedic-SafeExport.ps1')
. (Join-Path $root 'ADBMedic-Handoff.ps1')
$stage=Join-Path $root ('.test-work/handoff-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage)|Out-Null
$passed=0
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw ('Handoff test failed: '+$Message)};$script:passed++}
function Write-Fixture([string]$Session,[string]$Name,[string]$Text){[IO.File]::WriteAllText((Join-Path $Session $Name),$Text,([Text.UTF8Encoding]::new($false)))}
function New-Fixture([string]$Name){
    $session=Join-Path $stage $Name
    [IO.Directory]::CreateDirectory($session)|Out-Null
    Write-Fixture $session 'profile.json' '{"model":"TEST_MODEL","android":"14","captured":"2000-01-01T00:00:00Z"}'
    Write-Fixture $session 'symptom.txt' 'Battery drain after background use. <script>TEST</script>'
    Write-Fixture $session 'top.txt' 'TEST_OEM_FORMAT com.example.synthetic u0_a123 PID 4242'
    Write-Fixture $session 'battery.txt' "Time on battery: 2h 0m`nComputed drain: 66.2, actual drain: 0-100`nUid u0a123: 470 (cpu=2.0)`nWake lock TEST_WAKE: 40 times"
    Write-Fixture $session 'packages.txt' 'package:com.example.synthetic uid:10123'
    Write-Fixture $session 'jobs.txt' 'Command failed: TEST_PERMISSION_DENIED'
    Write-Fixture $session 'collection.json' '[{"file":"top.txt","startedUtc":"2000-01-01T00:00:00Z","finishedUtc":"2000-01-01T00:00:08Z","exitCode":0},{"file":"jobs.txt","startedUtc":"2000-01-01T00:00:08Z","finishedUtc":"2000-01-01T00:00:09Z","exitCode":1}]'
    return $session
}
try{
    foreach($ui in @('ru','en')){
        $session=New-Fixture $ui
        Write-Fixture $session 'unrelated.txt' 'TEST_UNRELATED_DATA'
        $bundle=New-ADBMedicDiagnosticBundle $session $ui
        Assert ($bundle.Ready -and $bundle.SchemaVersion -eq 2) 'schema 2 bundle is ready'
        $facts=Get-Content -LiteralPath (Join-Path $bundle.Directory 'facts.json') -Raw -Encoding UTF8|ConvertFrom-Json
        Assert ($facts.schemaVersion -eq 2 -and $facts.complaint.Contains('Battery drain')) 'complaint is preserved'
        Assert ($facts.device.model -ceq 'TEST_MODEL' -and $facts.device.android -ceq '14') 'device context is retained'
        Assert (-not ($facts.PSObject.Properties.Name -contains 'battery')) 'no misleading numeric projection is fabricated'
        Assert ($facts.analysis.version -eq 1 -and $facts.analysis.status -ceq 'unsupported') 'unknown fixture format remains explicit in the prepared analysis'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle.Directory 'SUMMARY.md')).Contains('unsupported')) 'standalone summary shows its coverage limitation'
        $top=$facts.sources|Where-Object file -eq 'evidence/top.txt'
        Assert ($top.status -eq 'collected' -and ([datetimeoffset]$top.startedUtc) -eq ([datetimeoffset]'2000-01-01T00:00:00Z') -and ([datetimeoffset]$top.finishedUtc) -eq ([datetimeoffset]'2000-01-01T00:00:08Z')) 'actual command interval is preserved'
        Assert (($facts.sources|Where-Object file -eq 'evidence/jobs.txt').status -eq 'failed') 'failed command is explicit'
        Assert (($facts.sources|Where-Object file -eq 'evidence/alarms.txt').status -eq 'missing') 'missing source is not zero'
        $battery=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'evidence/battery.txt'))
        Assert ($battery.Contains('66.2') -and $battery.Contains('470') -and $battery.Contains('40 times')) 'original counters and conflicting values remain inspectable'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle.Directory 'evidence/packages.txt')).Contains('com.example.synthetic')) 'real package identity is retained'
        $prompt=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'MANUAL-ANALYSIS-PROMPT.md'))
        foreach($phrase in @('Application evidence table','wake-lock acquisitions','measurement window','read-only ADB','Set-Content','expected result','Feedback template','self-contained','shared UID','Do not reset batterystats')){Assert ($prompt.Contains($phrase)) 'AI contract includes diagnostic and follow-up requirements'}
        Assert ($prompt.StartsWith($(if($ui -eq 'ru'){'Ты —'}else{'You are'}))) 'answer language is explicit'
        $starter=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'START-PROMPT.txt'))
        Assert ($starter -ceq $bundle.StarterPrompt -and $bundle.StarterPromptFile -ceq 'START-PROMPT.txt') 'copyable starter is saved beside the archive and returned to the console'
        Assert ($starter.Contains('ADBMedic-report.zip') -and $starter.Contains('MANUAL-ANALYSIS-PROMPT.md') -and $starter.Contains('facts.json')) 'starter directs the AI to the actual attachment and full instructions'
        Assert ($starter.Contains('('+$facts.language+')') -and ($starter.Contains('ADB-') -or $starter.Contains('ADB commands'))) 'starter includes answer locale and follow-up examination'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle.Directory 'REPORT.md')).Contains($starter)) 'report includes the exact copyable starter'
        $html=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'REPORT.html'))
        Assert (-not $html.Contains('<script>TEST</script>')) 'data is not rendered as executable HTML'
        $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $bundle.Directory $bundle.ArchiveName))
        try{
            $entries=@($zip.Entries|ForEach-Object {$_.FullName.Replace('\','/')})
            Assert ($entries -contains 'evidence/packages.txt' -and $entries -contains 'MANUAL-ANALYSIS-PROMPT.md') 'archive includes identities and full AI instructions'
            Assert ($entries -contains 'START-PROMPT.txt') 'starter is also included inside the ZIP'
            Assert ($entries -contains 'SUMMARY.md') 'prepared summary is included alongside complete raw evidence'
            Assert (-not ($entries -contains 'unrelated.txt') -and -not ($entries -contains 'profile.json')) 'only selected evidence and projected context are packaged'
        }finally{$zip.Dispose()}
        $blocked=$false;try{New-ADBMedicDiagnosticBundle $session $ui|Out-Null}catch{$blocked=$true}
        Assert $blocked 'existing archive is never overwritten'
    }
    foreach($locale in @('ru-RU','en-US','fr-FR','es-ES','pt-BR','zh-CN','de-DE')){
        $session=New-Fixture ('locale-'+$locale)
        $bundle=& (Join-Path $root 'Package-ADBMedic.ps1') -Session $session -Language $locale -PassThru
        $facts=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'facts.json'))|ConvertFrom-Json
        $prompt=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'MANUAL-ANALYSIS-PROMPT.md'))
        Assert ($facts.language -ceq $locale) 'packager preserves full requested locale'
        Assert ($facts.interfaceLanguage -ceq $(if($locale -eq 'ru-RU'){'ru'}else{'en'})) 'collector UI fallback is separate from AI language'
        Assert ($prompt.Contains('('+$locale+')') -and $prompt.Contains('that request takes precedence')) 'AI receives locale and explicit user preference priority'
        Assert (-not $prompt.Contains('Answer in clear English.') -and -not $prompt.Contains('Ответь по-русски')) 'UI template does not force the answer language'
    }
    $savedCulture=[Threading.Thread]::CurrentThread.CurrentUICulture
    try{
        [Threading.Thread]::CurrentThread.CurrentUICulture=[Globalization.CultureInfo]::GetCultureInfo('fr-FR')
        $session=New-Fixture 'windows-language'
        $bundle=& (Join-Path $root 'Package-ADBMedic.ps1') -Session $session -PassThru
        $facts=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'facts.json'))|ConvertFrom-Json
        Assert ($facts.language -ceq 'fr-FR' -and $facts.interfaceLanguage -ceq 'en') 'default uses Windows UI locale despite English interface fallback'
    }finally{[Threading.Thread]::CurrentThread.CurrentUICulture=$savedCulture}
    foreach($secret in @(('gh'+'p_'+('X'*36)),('api'+'_key = "TEST_SECRET_VALUE"'),(('-'*5)+'BEGIN '+'PRIVATE KEY'+('-'*5)),('Authorization: '+'Bearer TEST_SECRET_VALUE'))){
        $session=New-Fixture ([guid]::NewGuid().ToString('N'))
        Write-Fixture $session 'battery.txt' $secret
        $blocked=$false;try{New-ADBMedicDiagnosticBundle $session en|Out-Null}catch{$blocked=$true;Assert (-not $_.Exception.Message.Contains('TEST_SECRET_VALUE')) 'blocked export does not echo secret';Assert ($_.Exception.Data['ADBMedicReason'] -ceq 'secret') 'secret rejection has a safe structured reason'}
        Assert ($blocked -and -not(Test-Path -LiteralPath (Join-Path $session 'exports'))) 'synthetic secret blocks the whole export'
    }
    $session=New-Fixture 'invalid-time'
    Write-Fixture $session 'collection.json' '[{"file":"top.txt","startedUtc":"2000-01-02T00:00:00Z","finishedUtc":"2000-01-01T00:00:00Z","exitCode":0}]'
    $blocked=$false;try{New-ADBMedicDiagnosticBundle $session en|Out-Null}catch{$blocked=$true}
    Assert $blocked 'reversed capture interval is rejected'
    $session=New-Fixture 'large-evidence'
    Write-Fixture $session 'battery.txt' ([string]::new([char]'Z',17825792))
    $bundle=New-ADBMedicDiagnosticBundle $session en
    Assert ($bundle.Ready -and (Get-Item -LiteralPath (Join-Path $bundle.Directory 'evidence/battery.txt')).Length -eq 17825792) 'evidence above the former 16 MiB cap is retained in full'
    $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $bundle.Directory $bundle.ArchiveName))
    try{
        Assert ($zip.GetEntry('evidence/battery.txt').Length -eq 17825792) 'large evidence is not truncated inside the ZIP'
        Assert (@($zip.Entries|Where-Object {$_.FullName.Contains('\')}).Count -eq 0) 'ZIP paths use standard separators on every PowerShell engine'
    }finally{$zip.Dispose()}
    foreach($locale in @('ru-RU','en-US')){
        $session=New-Fixture ('oversize-'+$locale)
        $stream=[IO.File]::OpenWrite((Join-Path $session 'battery.txt'))
        try{$stream.SetLength((Get-ADBMedicHandoffLimits).FileBytes+1)}finally{$stream.Dispose()}
        $message=''
        try{& (Join-Path $root 'Package-ADBMedic.ps1') -Session $session -Language $locale -PassThru|Out-Null}catch{$message=$_.Exception.Message}
        Assert ($message.StartsWith('[ADBMEDIC-EXPORT] ') -and $message.Contains('battery.txt') -and $message.Contains('64')) 'oversize error identifies the known file and limit'
        Assert (-not $message.Contains($stage) -and -not(Test-Path -LiteralPath (Join-Path $session 'exports'))) 'size rejection hides private paths and creates no archive'
    }
    $session=New-Fixture 'secret-message'
    Write-Fixture $session 'battery.txt' ('gh'+'p_'+('X'*36))
    $message=''
    try{& (Join-Path $root 'Package-ADBMedic.ps1') -Session $session -Language en-US -PassThru|Out-Null}catch{$message=$_.Exception.Message}
    Assert ($message.Contains('possible secret') -and $message.Contains('battery.txt') -and -not $message.Contains(('X'*36)) -and -not $message.Contains($stage)) 'secret error gives actionable location without its value or private path'
    Write-Output ('Offline handoff tests: PASS ('+$passed+' assertions).')
}finally{
    $target=[IO.Path]::GetFullPath($stage)
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe cleanup target.'}
    if([IO.Directory]::Exists($target)){[IO.Directory]::Delete($target,$true)}
}
