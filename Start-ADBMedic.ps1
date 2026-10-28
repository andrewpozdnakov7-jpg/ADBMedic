[CmdletBinding()]
param(
    [ValidateSet('auto','codex','offline')][string]$Mode='offline',
    [string]$Language='auto',
    [switch]$SkipInstall,
    [switch]$SkipAI,
    [switch]$NoBrowser,
    [ValidateRange(1,86400)][int]$CommandTimeoutSeconds=1200
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
try {
$root=$PSScriptRoot
$work=Join-Path $env:LOCALAPPDATA 'ADBMedic\data'
New-Item -ItemType Directory -Force -Path $work | Out-Null
. (Join-Path $root 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
$t=Get-ADBMedicText -UI $locale.UI

function HasCommand([string]$name){return [bool](Get-Command $name -ErrorAction SilentlyContinue)}
function ConfirmAction([string]$question){return (Read-Host ($question+' [y/N]')) -match '^(y|yes|да|д)$'}
function EnsureAdb {
    if(HasCommand 'adb'){return 'adb'}
    $local=Join-Path $env:LOCALAPPDATA 'ADBMedic\tools\platform-tools\adb.exe'
    if(Test-Path -LiteralPath $local){return $local}
    if($SkipInstall){throw 'ADB missing. Download from https://developer.android.com/tools/releases/platform-tools'}
    if(-not (ConfirmAction $t.missingAdb)){throw 'ADB is required.'}
    $tools=Join-Path $env:LOCALAPPDATA 'ADBMedic\tools'
    New-Item -ItemType Directory -Force -Path $tools | Out-Null
    $zip=Join-Path $tools 'platform-tools.zip'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tools -Force
    Remove-Item -LiteralPath $zip -Force
    if(-not (Test-Path -LiteralPath $local)){throw 'ADB installation incomplete.'}
    return $local
}
. (Join-Path $root 'ADBMedic-Evidence.ps1')
. (Join-Path $root 'ADBMedic-Case.ps1')
function Capture([string]$name,[string[]]$argv,[string]$folder,[string]$adb,[string]$serial) {
    $record=Invoke-ADBMedicCapture $adb (@('-s',$serial)+$argv) $folder ($name+'.txt') $CommandTimeoutSeconds $name
    $captures.Add($record)
    Write-ADBMedicJson (Join-Path $folder 'collection.json') @($captures.ToArray())
}
# Retain old command-line parameters for compatibility. There is one available
# workflow: local collection and reports. No mode choice is needed.
$Mode='offline'
Write-Host 'ADBMedic' -ForegroundColor Cyan
. (Join-Path $root 'ADBMedic-Interactive.ps1')
if(-not $NoBrowser){
    $selection=Select-ADBMedicResumeCase $work $locale.UI
    if($selection.Action -eq 'exit'){return}
    if($selection.Action -eq 'resume'){
        if($selection.Case.Interrupted){Write-Warning (Get-ADBMedicInteractiveText $locale.UI).partial}
        Show-ADBMedicCaseMenu $selection.Case.Directory $selection.Case.Bundle $locale.UI
        return
    }
}
$adb=EnsureAdb
if(-not (ConfirmAction $t.collect)){Write-Host 'Cancelled';return}
$serverOutput=@(& $adb start-server 2>&1)
if($LASTEXITCODE -ne 0){throw 'ADB server failed.'}
. (Join-Path $root 'ADBMedic-Device.ps1')
$serial=Select-ADBMedicAdbDevice -Adb $adb -UI $locale.UI
if(-not $serial){return}
Write-Host 'ADB device ready.'
$symptom=Read-Host $t.symptom
if([string]::IsNullOrWhiteSpace($symptom)){$symptom=$t.noSymptom}
$folder=Join-Path $work ('session-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $folder | Out-Null
[IO.File]::WriteAllText((Join-Path $folder 'symptom.txt'),$symptom,[Text.Encoding]::UTF8)
@{captured=(Get-Date).ToString('o');model='unknown';android='unknown'} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'profile.json') -Encoding UTF8
@{requested=$Language;locale=$locale.Locale;ui=$locale.UI} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'locale.json') -Encoding UTF8

Write-Host $t.collecting -ForegroundColor Cyan
$captures=New-Object 'System.Collections.Generic.List[object]'
$state=Get-ADBMedicCaseState $folder
$state.answerLocale=$locale.Locale
$state|Add-Member -NotePropertyName interactiveVersion -NotePropertyValue 1 -Force
$state.target=[pscustomobject]@{adbSerial=$serial;fingerprintSha256=$null}
Write-ADBMedicJson (Join-Path $folder 'case.json') $state
foreach($check in Get-ADBMedicBaseline){Capture $check.id $check.arguments $folder $adb $serial}
$fingerprintRecord=$captures|Where-Object id -eq 'build-fingerprint'
$fingerprintPath=Join-Path $folder 'build-fingerprint.txt'
if($fingerprintRecord.status -eq 'collected' -and (Get-Item -LiteralPath $fingerprintPath).Length -gt 0){$state.target.fingerprintSha256=Get-ADBMedicHash $fingerprintPath}
Write-ADBMedicJson (Join-Path $folder 'case.json') $state
$preliminary=Join-Path $root 'Write-ADBMedicPreliminary.ps1'
$viewer=Join-Path $root 'Show-ADBMedicReport.ps1'
foreach($path in @($preliminary,$viewer)){
    if(-not (Test-Path -LiteralPath $path)){throw 'A required local project component is missing.'}
}

$bundle=$null
try{
    Write-Host $t.preparing -ForegroundColor Cyan
    $bundle=& (Join-Path $root 'Package-ADBMedic.ps1') -Session $folder -Language $locale.Locale -PassThru
}catch{
    $failure=[string]$_.Exception.Message
    if($failure.StartsWith('[ADBMEDIC-EXPORT] ')){Write-Warning $failure.Substring('[ADBMEDIC-EXPORT] '.Length)}else{Write-Warning $t.shareBlocked}
}
$privateReport=Join-Path $folder 'REPORT.md'
if($bundle -and $bundle.Ready){
    [IO.File]::Copy((Join-Path $bundle.Directory 'REPORT.md'),$privateReport,$true)
    [IO.File]::Copy((Join-Path $bundle.Directory 'REPORT.html'),(Join-Path $folder 'REPORT.html'),$true)
}else{
    & $preliminary -Session $folder -Language $locale.Locale -NoBrowser | Out-Null
}
Write-Host $t.reportReady -ForegroundColor Green
if($bundle -and $bundle.Ready){
    Write-Host $t.shareInstruction
    if($NoBrowser){Write-Host $t.starterPrompt;Write-Host $bundle.StarterPrompt}
}
if(-not $NoBrowser){Show-ADBMedicCaseMenu $folder $bundle $locale.UI $adb}
} catch {
    Write-Warning 'ADBMedic could not complete local diagnostics. Check ADB, USB authorization and local storage. Private error details are hidden.'
    exit 1
}
