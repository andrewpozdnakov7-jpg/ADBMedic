$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'ADBMedic-SafeExport.ps1')
$testRoot=Join-Path $root ('.test-work/share-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$shareTestState=@{Passed=0;Windows=0}
function Start-Process{$shareTestState.Windows++;throw 'Unexpected test window.'}
function Assert([bool]$Condition,[string]$Description){if(-not $Condition){throw ('Safe export test failed: '+$Description)};$shareTestState.Passed++}
function Write-FixtureText([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,([Text.UTF8Encoding]::new($true)))}
function New-Session([string]$Name){
    $path=Join-Path $testRoot $Name
    [IO.Directory]::CreateDirectory($path)|Out-Null
    $top=@'
Tasks: 2 total
800%cpu 80%user 0%nice 0%sys 720%idle 0%iow 0%irq 0%sirq 0%host
 PID USER PR NI VIRT RES SHR S[%CPU] %MEM TIME+ ARGS
 4242 u0_a123 20 0 1G 20M 1M R 60.0 0.1 0:01.00 com.example.synthetic_one TEST_PRIVATE_MARKER
 4243 u0_a124 20 0 1G 20M 1M S 20.0 0.1 0:01.00 com.example.synthetic_two
800%cpu 160%user 0%nice 0%sys 640%idle 0%iow 0%irq 0%sirq 0%host
 PID USER PR NI VIRT RES SHR S[%CPU] %MEM TIME+ ARGS
 4242 u0_a123 20 0 1G 20M 1M R 120.0 0.1 0:01.00 com.example.synthetic_one TEST_PRIVATE_MARKER
 4243 u0_a124 20 0 1G 20M 1M S 40.0 0.1 0:01.00 com.example.synthetic_two
'@
    Write-FixtureText (Join-Path $path 'top.txt') $top
    Write-FixtureText (Join-Path $path 'battery.txt') @'
Time on battery: 2h 2m 3s 4ms (90%) realtime, 1h 0m 0s (50%) uptime
Time on battery screen off: 1h 0m 0s (50%) realtime, 30m 0s (50%) uptime
Estimated power use (mAh):
Capacity: 4000, Computed drain: 7.5, actual drain: 5-10
Uid u0a123: 5.0 (cpu=3.0)
Uid u0a124: 2.5 (cpu=1.0)
'@
    Write-FixtureText (Join-Path $path 'power.txt') "mWakefulness=Awake`nmIsPowered=false"
    Write-FixtureText (Join-Path $path 'thermal.txt') 'Thermal Status: 1'
    Write-FixtureText (Join-Path $path 'symptom.txt') 'Battery drain TEST_PRIVATE_MARKER'
    Write-FixtureText (Join-Path $path 'profile.json') '{"model":"TEST_PRIVATE_MARKER"}'
    Write-FixtureText (Join-Path $path 'build.txt') 'TEST_PRIVATE_MARKER'
    return $path
}
function Assert-FactsRejected($Facts,[string]$Reason){$blocked=$false;try{Assert-ADBMedicSafeFacts $Facts}catch{$blocked=$true};Assert $blocked $Reason}
try{
    $session=New-Session 'TEST с пробелами'
    & (Join-Path $root 'Write-ADBMedicPreliminary.ps1') -Session $session -Language en-US|Out-Null
    Assert ($shareTestState.Windows -eq 0 -and (Test-Path -LiteralPath (Join-Path $session 'REPORT.html'))) 'standalone report generation also opens no window by default'
    $projection=ConvertFrom-ADBMedicSafeMeasurements $session ru
    $facts=$projection.Facts
    Assert ($facts.request -ceq 'battery' -and $facts.language -ceq 'ru') 'task is projected to a fixed category'
    Assert ($facts.cpuSamples.Count -eq 2 -and $facts.cpuSamples[0].busyPercent -eq 10 -and $facts.cpuSamples[1].busyPercent -eq 20) 'CPU normalization and sample boundaries are correct'
    Assert ($facts.cpuSamples[1].loads[0].cpuPercent -eq 120) 'per-core CPU values above 100 are retained'
    Assert ($facts.battery.windowMinutes -eq 122 -and $facts.battery.screenOffMinutes -eq 60) 'relative battery durations are retained in rounded minutes'
    Assert ($facts.battery.estimatedDrainMah -eq 7.5 -and $facts.battery.bySubject.Count -eq 2) 'useful historical energy estimates are retained'
    Assert ($facts.cpuSamples[0].loads[0].subject -ceq $facts.battery.bySubject[0].subject) 'CPU and battery labels join without exporting UID'
    Assert ($facts.power.powered -eq $false -and $facts.power.wakefulness -ceq 'awake' -and $facts.thermal.severity -eq 1) 'power and thermal context is retained'
    $json=$facts|ConvertTo-Json -Depth 8
    foreach($private in @('TEST_PRIVATE_MARKER','com.example','u0_a123','u0a123','4242','4000')){Assert (-not $json.Contains($private)) 'private/raw identity and capacity are absent from facts'}
    $roundtrip=$json|ConvertFrom-Json
    Assert-ADBMedicSafeFacts $roundtrip
    Assert ($projection.PrivateSubjects[0].Names.Count -gt 0) 'private mapping remains local and separate'
    $sensitive=@(('gh'+'p_'+('X'*36)),('C:'+[char]92+'Users'+[char]92+'TEST_PROFILE'),('TEST_PERSON'+'@'+'privacy-test.invalid'),('12345'+'67890'+'12345'),(('-'*5)+'BEGIN '+'PRIVATE KEY'+('-'*5)))
    foreach($language in @('ru','en')){
        $candidate=New-Session ('TEST '+$language)
        $top=[IO.File]::ReadAllText((Join-Path $candidate 'top.txt')).Replace('TEST_PRIVATE_MARKER',('TEST_PRIVATE_MARKER '+($sensitive -join ' ')))
        Write-FixtureText (Join-Path $candidate 'top.txt') $top
        Write-FixtureText (Join-Path $candidate 'symptom.txt') ('Battery drain '+($sensitive -join ' '))
        $bundle=New-ADBMedicSafeBundle $candidate $language
        Assert ($bundle.Ready -and (Test-Path -LiteralPath (Join-Path $bundle.Directory $bundle.ArchiveName))) 'validated ZIP is created'
        Assert (@(Get-ChildItem -LiteralPath $bundle.Directory -File).Count -eq 5) 'public folder contains only four share files and ZIP'
        $archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $bundle.Directory $bundle.ArchiveName))
        try{
            Assert ($archive.Entries.Count -eq 4) 'ZIP contains only the four allowed documents'
            foreach($entry in $archive.Entries){
                Assert ($entry.LastWriteTime.Year -eq 2000 -and $entry.LastWriteTime.Month -eq 1 -and $entry.LastWriteTime.Day -eq 1) 'ZIP metadata does not expose collection time'
                $reader=New-Object IO.StreamReader($entry.Open(),([Text.UTF8Encoding]::new($false,$true)))
                try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
                foreach($private in @('TEST_PRIVATE_MARKER','com.example','u0_a123','u0a123','4242')){Assert (-not $text.Contains($private)) 'no private marker leaks into any ZIP document'}
                foreach($private in $sensitive){Assert (-not $text.Contains($private)) 'synthetic keys, email, profile and hardware numbers are absent from ZIP'}
            }
        }finally{$archive.Dispose()}
        $prompt=[IO.File]::ReadAllText((Join-Path $bundle.Directory 'MANUAL-ANALYSIS-PROMPT.md'))
        Assert ($prompt.Contains('1.') -and $prompt.Contains('5.') -and $prompt.Contains('facts.json')) 'assistant instructions require evidence, actions and feedback'
        $blocked=$false;try{New-ADBMedicSafeBundle $candidate $language|Out-Null}catch{$blocked=$true}
        Assert $blocked 'existing export is not overwritten or reused blindly'
    }
    $mutated=$json|ConvertFrom-Json
    $mutated|Add-Member -NotePropertyName extra -NotePropertyValue 'TEST_PRIVATE_MARKER'
    Assert-FactsRejected $mutated 'unexpected fields are rejected'
    $mutated=$json|ConvertFrom-Json;$mutated.cpuSamples[0].busyPercent='TEST_PRIVATE_MARKER'
    Assert-FactsRejected $mutated 'strings cannot pass as measurements'
    $mutated=$json|ConvertFrom-Json;$mutated.cpuSamples[0].busyPercent=[double]::NaN
    Assert-FactsRejected $mutated 'nonfinite values are rejected'
    $mutated=$json|ConvertFrom-Json;$mutated.cpuSamples[0].loads[0].subject='TEST_PRIVATE_MARKER'
    Assert-FactsRejected $mutated 'arbitrary subject names are rejected'
    $mutated=$json|ConvertFrom-Json;$mutated.battery.screenOffMinutes=9999
    Assert-FactsRejected $mutated 'inconsistent time windows are rejected'

    $candidate=New-Session 'TEST tamper'
    $bundle=New-ADBMedicSafeBundle $candidate en
    $inspect=Join-Path $testRoot 'TEST inspect'
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $bundle.Directory $bundle.ArchiveName),$inspect)
    foreach($name in @('REPORT.md','REPORT.html','MANUAL-ANALYSIS-PROMPT.md','facts.json')){
        $file=Join-Path $inspect $name;$original=[IO.File]::ReadAllText($file)
        [IO.File]::AppendAllText($file,'TEST_PRIVATE_MARKER')
        $blocked=$false;try{Assert-ADBMedicShareDirectory $inspect (Join-Path $testRoot 'TEST verify') }catch{$blocked=$true}
        Assert $blocked 'independent gate detects added private text in every document'
        [IO.File]::WriteAllText($file,$original,([Text.UTF8Encoding]::new($false)))
    }
    Write-FixtureText (Join-Path $inspect 'TEST_EXTRA.txt') 'TEST_PRIVATE_MARKER'
    $blocked=$false;try{Assert-ADBMedicShareDirectory $inspect (Join-Path $testRoot 'TEST verify-extra')}catch{$blocked=$true}
    Assert $blocked 'extra share files are rejected'

    $candidate=New-Session 'TEST unknown'
    foreach($name in @('top.txt','battery.txt','power.txt','thermal.txt')){Write-FixtureText (Join-Path $candidate $name) 'TEST_UNKNOWN_FORMAT'}
    $blocked=$false;try{New-ADBMedicSafeBundle $candidate en|Out-Null}catch{$blocked=$true}
    Assert ($blocked -and -not(Test-Path -LiteralPath (Join-Path $candidate 'exports'))) 'unknown formats create no archive'
    $candidate=New-Session 'TEST invalid numbers'
    $top=[IO.File]::ReadAllText((Join-Path $candidate 'top.txt')).Replace('720%idle','9999%idle')
    Write-FixtureText (Join-Path $candidate 'top.txt') $top
    $blocked=$false;try{New-ADBMedicSafeBundle $candidate en|Out-Null}catch{$blocked=$true}
    Assert ($blocked -and -not(Test-Path -LiteralPath (Join-Path $candidate 'exports'))) 'invalid measurements fail closed'
    $candidate=New-Session 'TEST conflicting windows'
    [IO.File]::AppendAllText((Join-Path $candidate 'battery.txt'),"`nTime on battery: 5h 0m 0s (50%) realtime, 1h 0m 0s (50%) uptime")
    $blocked=$false;try{New-ADBMedicSafeBundle $candidate en|Out-Null}catch{$blocked=$true}
    Assert ($blocked -and -not(Test-Path -LiteralPath (Join-Path $candidate 'exports'))) 'conflicting battery windows cannot be combined silently'
    $external=New-Session 'TEST external'
    $candidate=New-Session 'TEST links'
    $link=Join-Path $candidate 'top.txt'
    [IO.File]::Delete($link)
    New-Item -ItemType Junction -Path $link -Target $external|Out-Null
    $blocked=$false;try{New-ADBMedicSafeBundle $candidate en|Out-Null}catch{$blocked=$true}
    Assert ($blocked -and -not(Test-Path -LiteralPath (Join-Path $candidate 'exports'))) 'linked diagnostic inputs are rejected'
    [IO.Directory]::Delete($link)
    Write-Host ('Offline safe export tests: PASS ('+$shareTestState.Passed+' assertions).')
}finally{
    $target=[IO.Path]::GetFullPath($testRoot)
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe synthetic cleanup target.'}
    if([IO.Directory]::Exists($target)){[IO.Directory]::Delete($target,$true)}
}
