$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$testRoot=Join-Path $root ('.test-work/runtime-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$savedLocalData=$env:LOCALAPPDATA
$savedTemp=$env:TEMP
$savedUICulture=[Threading.Thread]::CurrentThread.CurrentUICulture
$runtimeTestState=@{Case='success'; Calls=@(); Network=0; Cloud=0; Browser=0; Prompts=0; PromptTexts=@(); Opened=@(); FailFirstOpen=$false; Passed=0; LocaleReads=0}
function Assert([bool]$Condition,[string]$Description) {
    if (-not $Condition) { throw ('Runtime safety test failed: '+$Description) }
    $runtimeTestState.Passed++
}
function Invoke-WebRequest { $runtimeTestState.Network++; throw 'Unexpected test network call.' }
function Invoke-RestMethod { $runtimeTestState.Network++; throw 'Unexpected test network call.' }
function codex { $runtimeTestState.Cloud++; throw 'Unexpected test cloud call.' }
function Start-Process {
    param($FilePath,$ArgumentList)
    $runtimeTestState.Browser++
    $runtimeTestState.Opened+=@([pscustomobject]@{File=$FilePath;Arguments=$ArgumentList})
    if($runtimeTestState.FailFirstOpen -and $runtimeTestState.Browser -eq 1){throw 'TEST_PRIVATE_PROVIDER_DETAIL'}
}
function Get-Command {
    param($Name,$ErrorAction)
    if ($Name -eq 'adb' -and $runtimeTestState.Case -eq 'missing-adb') { return $null }
    return Microsoft.PowerShell.Core\Get-Command -Name $Name -ErrorAction SilentlyContinue
}
function Read-Host {
    param($Prompt)
    $runtimeTestState.Prompts++
    $runtimeTestState.PromptTexts+=@([string]$Prompt)
    if ($runtimeTestState.Case -eq 'decline') { return 'n' }
    if ($runtimeTestState.Prompts -eq 1) { return 'y' }
    if($runtimeTestState.Case -eq 'menu'){
        switch($runtimeTestState.Prompts){2{return 'Battery drain'};3{return 'invalid'};4{return '1'};5{return '2'};default{return ''}}
    }
    if($runtimeTestState.Case -eq 'menu-exit' -and $runtimeTestState.Prompts -ge 3){return ''}
    if ($runtimeTestState.Case -in @('enumeration-failure','unauthorized','offline','no-device')) { return 'q' }
    return 'TEST_SYNTHETIC_SYMPTOM'
}
function adb {
    $runtimeTestState.Calls += ,@($args)
    $global:LASTEXITCODE=0
    if ($args[0] -eq 'start-server') { return 'TEST_LOCAL_SERVER' }
    if ($args[0] -eq 'devices') {
        if ($runtimeTestState.Case -eq 'enumeration-failure') { $global:LASTEXITCODE=1; return 'TEST_PRIVATE_PROVIDER_DETAIL' }
        if ($runtimeTestState.Case -eq 'no-device') { return 'List of devices attached' }
        if ($runtimeTestState.Case -eq 'unauthorized') { return 'TEST_SERIAL_001 unauthorized' }
        if ($runtimeTestState.Case -eq 'offline') { return 'TEST_SERIAL_001 offline' }
        return 'TEST_SERIAL_001 device product:synthetic'
    }
    if ($args[0] -ne '-s' -or $args[2] -ne 'shell') { throw 'Unexpected synthetic ADB command.' }
    if ($args[3] -eq 'getprop') {
        if ($args[4] -eq 'ro.product.model') { return 'TEST_MODEL' }
        if ($args[4] -eq 'ro.build.version.release') { return '14' }
        return 'TEST_SYNTHETIC_BUILD'
    }
    if($args[3] -eq 'pm'){
        if(($args[4..6] -join ' ') -ne 'list packages -U'){throw 'Unexpected package operation.'}
        return 'package:com.example.synthetic uid:10123'
    }
    if ($args[3] -notin @('dumpsys','top')) { throw 'Unexpected synthetic ADB shell operation.' }
    if($args[3] -eq 'top'){
        if($runtimeTestState.Case -eq 'unsupported'){return 'TEST_UNKNOWN_FORMAT'}
        return @('800%cpu 80%user 0%nice 0%sys 720%idle 0%iow 0%irq 0%sirq 0%host','PID USER PR NI VIRT RES SHR S[%CPU] %MEM TIME+ ARGS','4242 u0_a123 20 0 1G 20M 1M R 80.0 0.1 0:01.00 com.example.synthetic')
    }
    if($args[4] -eq 'batterystats'){
        if($runtimeTestState.Case -eq 'unsupported'){return 'TEST_UNKNOWN_FORMAT'}
        return @('Time on battery: 2h 0m 0s (50%) realtime, 1h 0m 0s (50%) uptime','Uid u0a123: 3.0 (cpu=2.0)')
    }
    if($args[4] -eq 'power'){return @('mWakefulness=Awake','mIsPowered=false')}
    if($args[4] -eq 'thermalservice'){return 'Thermal Status: 0'}
    return 'TEST_SYNTHETIC_CAPTURE'
}
function Get-Content {
    param($LiteralPath,$Path,$Raw,$Encoding,$TotalCount,$ErrorAction)
    if ($LiteralPath -and $LiteralPath.StartsWith((Join-Path $testRoot 'TEST_PRIVATE_SESSION'))) {
        $runtimeTestState.LocaleReads++
        throw 'Private session should not be read by disabled entry points.'
    }
    $parameters=@{}
    foreach ($key in $PSBoundParameters.Keys) { $parameters[$key]=$PSBoundParameters[$key] }
    return Microsoft.PowerShell.Management\Get-Content @parameters
}
try {
    $env:LOCALAPPDATA=$testRoot
    $env:TEMP=$testRoot
    $privateSession=Join-Path $testRoot 'TEST_PRIVATE_SESSION'
    [IO.Directory]::CreateDirectory($privateSession) | Out-Null
    [IO.File]::WriteAllText((Join-Path $privateSession 'locale.json'),'TEST_NOT_VALID_JSON')
    foreach ($language in @('ru-RU','en-US','auto')) {
        $blocked=$false
        try { & (Join-Path $root 'Package-ADBMedic.ps1') -Session $privateSession -Language $language | Out-Null }
        catch {
            $blocked=$true
            Assert (-not $_.Exception.Message.Contains($testRoot)) 'blocked export error hides local profile path'
        }
        Assert $blocked 'raw export remains blocked'
        & (Join-Path $root 'Analyze-ADBMedic.ps1') -Session $privateSession -Language $language -NoBrowser -WarningAction SilentlyContinue | Out-Null
    }
    Assert ($runtimeTestState.LocaleReads -eq 0) 'disabled export and cloud analyzer do not read session locale'
    Assert (@(Get-ChildItem -LiteralPath $testRoot -Recurse -Filter '*.zip').Count -eq 0) 'blocked entry points create no ZIP'

    foreach ($case in @('decline','missing-adb','enumeration-failure','unauthorized','offline','no-device','success')) {
        $runtimeTestState.Case=$case
        $runtimeTestState.Prompts=0
        $runtimeTestState.Calls=@()
        $log=@(& (Join-Path $root 'Start-ADBMedic.ps1') -Mode offline -Language en-US -NoBrowser -SkipInstall *>&1)
        $display=$log -join "`n"
        Assert ($display.Contains('START-PROMPT.txt') -eq ($case -eq 'success')) 'starter is printed only for a completed archive'
        Assert (-not $display.Contains('TEST_SERIAL_001')) 'console does not expose USB identifier'
        Assert (-not $display.Contains('TEST_PRIVATE_PROVIDER_DETAIL')) 'console hides provider error details'
        Assert (-not $display.Contains($testRoot)) 'console does not expose private local path'
        if ($case -eq 'decline') { Assert ($runtimeTestState.Calls.Count -eq 0) 'collection refusal runs no ADB commands' }
        if ($case -eq 'missing-adb') { Assert ($runtimeTestState.Calls.Count -eq 0) 'missing ADB fails without device access or download' }
    }
    $sessions=@(Get-ChildItem -LiteralPath (Join-Path $testRoot 'ADBMedic/data') -Directory)
    Assert ($sessions.Count -eq 1) 'only successful synthetic collection creates a session'
    foreach ($name in @('profile.json','symptom.txt','cpu.txt','top.txt','battery.txt','battery-state.txt','power.txt','thermal.txt','camera.txt','sensors.txt','packages.txt','alarms.txt','jobs.txt','deviceidle.txt','collection.json','REPORT.md','REPORT.html')) {
        Assert (Test-Path -LiteralPath (Join-Path $sessions[0].FullName $name)) 'local collection and report output is retained'
    }
    foreach ($call in $runtimeTestState.Calls) {
        Assert ($call[0] -in @('start-server','devices','-s')) 'only expected ADB entry points are used'
        Assert (@($call | Where-Object { $_ -in @('root','reboot','kill','kill-server','install','uninstall','disable','clear','flash','setprop') }).Count -eq 0) 'no device changes are requested'
    }
    foreach($culture in @('ru-RU','en-US')) {
        [Threading.Thread]::CurrentThread.CurrentUICulture=[Globalization.CultureInfo]::GetCultureInfo($culture)
        $runtimeTestState.Case='no-device'
        $runtimeTestState.Prompts=0
        $runtimeTestState.PromptTexts=@()
        $log=@(& (Join-Path $root 'bootstrap.ps1') *>&1)
        Assert ($runtimeTestState.Prompts -eq 2) 'plain bootstrap asks only for collection consent and device retry'
        $expectedPrompt=if($culture -eq 'ru-RU'){'Собирать диагностические данные?'}else{'Collect diagnostics?'}
        Assert ($runtimeTestState.PromptTexts[0].StartsWith($expectedPrompt)) 'plain bootstrap uses the Windows UI language'
        Assert (-not (($log -join "`n") -match 'Mode|Codex|offline')) 'plain bootstrap has no technical mode choices'
    }
    Assert ($runtimeTestState.Network -eq 0 -and $runtimeTestState.Cloud -eq 0 -and $runtimeTestState.Browser -eq 0) 'synthetic diagnostics make no network/cloud/browser calls'
    $runtimeTestState.Case='menu-exit';$runtimeTestState.Prompts=0
    $log=@(& (Join-Path $root 'bootstrap.ps1') *>&1)
    Assert ($runtimeTestState.Browser -eq 0) 'default successful run opens no browser or folder'
    Assert (($log -join "`n").Contains('ADBMedic-report.zip')) 'terminal explains which prepared archive to give the AI chat'
    $runtimeTestState.Case='menu';$runtimeTestState.Prompts=0;$runtimeTestState.FailFirstOpen=$true
    $log=@(& (Join-Path $root 'bootstrap.ps1') *>&1)
    Assert ($runtimeTestState.Browser -eq 2) 'only explicit report/folder choices launch windows'
    Assert ($runtimeTestState.Opened[0].File.EndsWith('REPORT.html') -and $runtimeTestState.Opened[1].File -ceq 'explorer.exe') 'menu opens the report and the correct shell'
    Assert ($runtimeTestState.Opened[1].Arguments.EndsWith('exports"')) 'folder choice shows only prepared share files'
    Assert (-not (($log -join "`n").Contains('TEST_PRIVATE_PROVIDER_DETAIL'))) 'open-window failure is hidden and menu recovers'
    Assert ($runtimeTestState.Network -eq 0 -and $runtimeTestState.Cloud -eq 0) 'manual handoff never uploads automatically'
    $before=@(Get-ChildItem -LiteralPath (Join-Path $testRoot 'ADBMedic/data') -Directory | ForEach-Object{$_.FullName})
    $runtimeTestState.Case='unsupported';$runtimeTestState.Prompts=0
    $log=@(& (Join-Path $root 'bootstrap.ps1') -NoBrowser *>&1)
    $created=@(Get-ChildItem -LiteralPath (Join-Path $testRoot 'ADBMedic/data') -Directory | Where-Object{$before -notcontains $_.FullName})
    Assert ($created.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $created[0].FullName 'exports/ADBMedic-report.zip'))) 'unrecognized OEM evidence is retained for the diagnostic analyst'
    $handoff=[IO.File]::ReadAllText((Join-Path $created[0].FullName 'exports/facts.json'))|ConvertFrom-Json
    Assert ($handoff.schemaVersion -eq 2 -and $handoff.complaint -ceq 'TEST_SYNTHETIC_SYMPTOM') 'runtime handoff preserves complaint in schema 2'
    Write-Host ('Offline runtime safety tests: PASS ('+$runtimeTestState.Passed+' assertions).')
} finally {
    $env:LOCALAPPDATA=$savedLocalData
    $env:TEMP=$savedTemp
    [Threading.Thread]::CurrentThread.CurrentUICulture=$savedUICulture
    $target=[IO.Path]::GetFullPath($testRoot)
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    if (-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup target.' }
    if ([IO.Directory]::Exists($target)) { [IO.Directory]::Delete($target,$true) }
}
