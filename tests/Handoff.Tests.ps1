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
        $top=$facts.sources|Where-Object file -eq 'evidence/top.txt'
        Assert ($top.status -eq 'collected' -and $top.startedUtc -ceq '2000-01-01T00:00:00Z' -and $top.finishedUtc -ceq '2000-01-01T00:00:08Z') 'actual command interval is preserved'
        Assert (($facts.sources|Where-Object file -eq 'evidence/jobs.txt').status -eq 'failed') 'failed command is explicit'
        Assert (($facts.sources|Where-Object file -eq 'evidence/alarms.txt').status -eq 'missing') 'missing source is not zero'
        $battery=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'evidence/battery.txt'))
        Assert ($battery.Contains('66.2') -and $battery.Contains('470') -and $battery.Contains('40 times')) 'original counters and conflicting values remain inspectable'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle.Directory 'evidence/packages.txt')).Contains('com.example.synthetic')) 'real package identity is retained'
        $prompt=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'MANUAL-ANALYSIS-PROMPT.md'))
        foreach($phrase in @('Application evidence table','wake-lock acquisitions','measurement window','read-only ADB','Set-Content','expected result','Feedback template','self-contained','shared UID','Do not reset batterystats')){Assert ($prompt.Contains($phrase)) 'AI contract includes diagnostic and follow-up requirements'}
        Assert ($prompt.StartsWith($(if($ui -eq 'ru'){'Ты —'}else{'You are'}))) 'answer language is explicit'
        $html=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'REPORT.html'))
        Assert (-not $html.Contains('<script>TEST</script>')) 'data is not rendered as executable HTML'
        $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $bundle.Directory $bundle.ArchiveName))
        try{
            $entries=@($zip.Entries|ForEach-Object {$_.FullName.Replace('\','/')})
            Assert ($entries -contains 'evidence/packages.txt' -and $entries -contains 'MANUAL-ANALYSIS-PROMPT.md') 'archive includes identities and full AI instructions'
            Assert (-not ($entries -contains 'unrelated.txt') -and -not ($entries -contains 'profile.json')) 'only selected evidence and projected context are packaged'
        }finally{$zip.Dispose()}
        $blocked=$false;try{New-ADBMedicDiagnosticBundle $session $ui|Out-Null}catch{$blocked=$true}
        Assert $blocked 'existing archive is never overwritten'
    }
    foreach($secret in @(('gh'+'p_'+('X'*36)),('api'+'_key = "TEST_SECRET_VALUE"'),(('-'*5)+'BEGIN '+'PRIVATE KEY'+('-'*5)),('Authorization: '+'Bearer TEST_SECRET_VALUE'))){
        $session=New-Fixture ([guid]::NewGuid().ToString('N'))
        Write-Fixture $session 'battery.txt' $secret
        $blocked=$false;try{New-ADBMedicDiagnosticBundle $session en|Out-Null}catch{$blocked=$true;Assert (-not $_.Exception.Message.Contains('TEST_SECRET_VALUE')) 'blocked export does not echo secret'}
        Assert ($blocked -and -not(Test-Path -LiteralPath (Join-Path $session 'exports'))) 'synthetic secret blocks the whole export'
    }
    $session=New-Fixture 'invalid-time'
    Write-Fixture $session 'collection.json' '[{"file":"top.txt","startedUtc":"2000-01-02T00:00:00Z","finishedUtc":"2000-01-01T00:00:00Z","exitCode":0}]'
    $blocked=$false;try{New-ADBMedicDiagnosticBundle $session en|Out-Null}catch{$blocked=$true}
    Assert $blocked 'reversed capture interval is rejected'
    Write-Output ('Offline handoff tests: PASS ('+$passed+' assertions).')
}finally{
    $target=[IO.Path]::GetFullPath($stage)
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe cleanup target.'}
    if([IO.Directory]::Exists($target)){[IO.Directory]::Delete($target,$true)}
}
