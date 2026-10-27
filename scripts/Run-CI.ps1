[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$savedTemp=$env:TEMP
$savedTmp=$env:TMP
try{
    $stage=Join-Path $root '.test-work'
    [IO.Directory]::CreateDirectory($stage)|Out-Null
    $env:TEMP=$stage
    $env:TMP=$stage
    Write-Output ('PowerShell '+$PSVersionTable.PSVersion.ToString())
    $engine=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'})
    # Run each test suite in a separate process to isolate its fixtures and temporary state.
    foreach($script in @('smoke-test.ps1','tests/SafeExport.Tests.ps1','tests/Runtime-Safety.Tests.ps1','tests/Install-ADBMedic.Tests.ps1','tests/Launch.Tests.ps1')){
        & $engine -NoLogo -NoProfile -NonInteractive -File (Join-Path $root $script)
        if($LASTEXITCODE -ne 0){throw 'An offline test suite failed.'}
    }
    Write-Output 'All offline CI suites: PASS'
}finally{
    $env:TEMP=$savedTemp
    $env:TMP=$savedTmp
}
