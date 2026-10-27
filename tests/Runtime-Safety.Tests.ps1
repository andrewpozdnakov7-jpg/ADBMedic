$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$testRoot=Join-Path $root ('.test-work/runtime-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$savedLocalData=$env:LOCALAPPDATA
$savedTemp=$env:TEMP
$savedUICulture=[Threading.Thread]::CurrentThread.CurrentUICulture
$runtimeTestState=@{Case='success'; Calls=@(); Network=0; Cloud=0; Browser=0; Prompts=0; PromptTexts=@(); Passed=0; LocaleReads=0}
function Assert([bool]$Condition,[string]$Description) {
    if (-not $Condition) { throw ('Runtime safety test failed: '+$Description) }
    $runtimeTestState.Passed++
}
function Invoke-WebRequest { $runtimeTestState.Network++; throw 'Unexpected test network call.' }
function Invoke-RestMethod { $runtimeTestState.Network++; throw 'Unexpected test network call.' }
function codex { $runtimeTestState.Cloud++; throw 'Unexpected test cloud call.' }
function Start-Process { $runtimeTestState.Browser++; throw 'Unexpected test browser call.' }
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
    if ($args[3] -notin @('dumpsys','top')) { throw 'Unexpected synthetic ADB shell operation.' }
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
        Assert (-not $display.Contains('TEST_SERIAL_001')) 'console does not expose USB identifier'
        Assert (-not $display.Contains('TEST_PRIVATE_PROVIDER_DETAIL')) 'console hides provider error details'
        Assert (-not $display.Contains($testRoot)) 'console does not expose private local path'
        if ($case -eq 'decline') { Assert ($runtimeTestState.Calls.Count -eq 0) 'collection refusal runs no ADB commands' }
        if ($case -eq 'missing-adb') { Assert ($runtimeTestState.Calls.Count -eq 0) 'missing ADB fails without device access or download' }
    }
    $sessions=@(Get-ChildItem -LiteralPath (Join-Path $testRoot 'ADBMedic/data') -Directory)
    Assert ($sessions.Count -eq 1) 'only successful synthetic collection creates a session'
    foreach ($name in @('profile.json','symptom.txt','cpu.txt','top.txt','battery.txt','power.txt','thermal.txt','camera.txt','sensors.txt','build.txt','REPORT.md','REPORT.html')) {
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
