$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$launchTestState=@{Calls=0; Failed=$false; Passed=0}
function Assert([bool]$Condition,[string]$Description) {
    if(-not $Condition){throw ('Launch test failed: '+$Description)}
    $launchTestState.Passed++
}
function Invoke-WebRequest {
    param($Uri,[switch]$UseBasicParsing,$TimeoutSec)
    $launchTestState.Calls++
    if($Uri -cne 'https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/Install-ADBMedic.ps1'){throw 'Unexpected source endpoint.'}
    if($launchTestState.Failed){throw 'TEST_PRIVATE_PROVIDER_DETAIL'}
    return @{Content=([string][char]0xFEFF+@'
param([switch]$Launch)
[pscustomobject]@{Type='SyntheticPublicLaunch'; Launch=[bool]$Launch}
'@)}
}
$source=[IO.File]::ReadAllText((Join-Path $root 'run.ps1'))
$result=@($source | Invoke-Expression)
Assert ($launchTestState.Calls -eq 1) 'one public command fetches the installer once'
Assert ($result.Count -eq 1 -and $result[0].Type -eq 'SyntheticPublicLaunch' -and $result[0].Launch) 'public command starts the application without flags'
$launchTestState.Failed=$true
$blocked=$false
try{$source | Invoke-Expression | Out-Null}
catch{
    $blocked=$true
    Assert (-not $_.Exception.Message.Contains('TEST_PRIVATE_PROVIDER_DETAIL')) 'public launcher hides provider details'
}
Assert $blocked 'public launcher fails closed when download fails'
Write-Host ('Offline launch tests: PASS ('+$launchTestState.Passed+' assertions).')
