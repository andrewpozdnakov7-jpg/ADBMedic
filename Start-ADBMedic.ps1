[CmdletBinding()]
param(
    [ValidateSet('auto','codex','offline')][string]$Mode='offline',
    [string]$Language='auto',
    [switch]$SkipInstall,
    [switch]$SkipAI,
    [switch]$NoBrowser
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
function Capture([string]$name,[string[]]$argv,[string]$folder,[string]$adb,[string]$serial) {
    $path=Join-Path $folder ($name+'.txt')
    $started=[DateTime]::UtcNow.ToString('o')
    $code=$null
    try{
        $text=(& $adb -s $serial @argv 2>&1 | Out-String)
        $code=$LASTEXITCODE
        if($code -ne 0){$text='Command failed: '+$text}
        [IO.File]::WriteAllText($path,$text,[Text.Encoding]::UTF8)
    }catch{
        [IO.File]::WriteAllText($path,'Capture failed: '+$_.Exception.Message,[Text.Encoding]::UTF8)
    }finally{
        $captures.Add([pscustomobject]@{file=($name+'.txt');command=($argv -join ' ');startedUtc=$started;finishedUtc=[DateTime]::UtcNow.ToString('o');exitCode=$code})
    }
}

# Retain old command-line parameters for compatibility. There is one available
# workflow: local collection and reports. No mode choice is needed.
$Mode='offline'
Write-Host 'ADBMedic' -ForegroundColor Cyan
$adb=EnsureAdb
if(-not (ConfirmAction $t.collect)){Write-Host 'Cancelled';return}
$serverOutput=@(& $adb start-server 2>&1)
if($LASTEXITCODE -ne 0){throw 'ADB server failed.'}
. (Join-Path $root 'ADBMedic-Device.ps1')
$serial=Select-ADBMedicAdbDevice -Adb $adb -UI $locale.UI
if(-not $serial){return}
$model=(& $adb -s $serial shell getprop ro.product.model | Out-String).Trim()
$android=(& $adb -s $serial shell getprop ro.build.version.release | Out-String).Trim()
Write-Host 'ADB device ready.'
$symptom=Read-Host $t.symptom
if([string]::IsNullOrWhiteSpace($symptom)){$symptom=$t.noSymptom}
$folder=Join-Path $work ('session-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $folder | Out-Null
[IO.File]::WriteAllText((Join-Path $folder 'symptom.txt'),$symptom,[Text.Encoding]::UTF8)
@{captured=(Get-Date).ToString('o');model=$model;android=$android} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'profile.json') -Encoding UTF8
@{requested=$Language;locale=$locale.Locale;ui=$locale.UI} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'locale.json') -Encoding UTF8

Write-Host $t.collecting -ForegroundColor Cyan
$captures=New-Object 'System.Collections.Generic.List[object]'
Capture 'cpu' @('shell','dumpsys','cpuinfo') $folder $adb $serial
Capture 'top' @('shell','top','-b','-d','2','-n','3') $folder $adb $serial
Capture 'battery' @('shell','dumpsys','batterystats') $folder $adb $serial
Capture 'battery-state' @('shell','dumpsys','battery') $folder $adb $serial
Capture 'power' @('shell','dumpsys','power') $folder $adb $serial
Capture 'thermal' @('shell','dumpsys','thermalservice') $folder $adb $serial
Capture 'camera' @('shell','dumpsys','media.camera') $folder $adb $serial
Capture 'sensors' @('shell','dumpsys','sensorservice') $folder $adb $serial
Capture 'packages' @('shell','pm','list','packages','-U','--user','current') $folder $adb $serial
Capture 'alarms' @('shell','dumpsys','alarm') $folder $adb $serial
Capture 'jobs' @('shell','dumpsys','jobscheduler') $folder $adb $serial
Capture 'deviceidle' @('shell','dumpsys','deviceidle') $folder $adb $serial
[IO.File]::WriteAllText((Join-Path $folder 'collection.json'),(ConvertTo-Json -InputObject @($captures.ToArray()) -Depth 5),[Text.Encoding]::UTF8)

$preliminary=Join-Path $root 'Write-ADBMedicPreliminary.ps1'
$viewer=Join-Path $root 'Show-ADBMedicReport.ps1'
foreach($path in @($preliminary,$viewer)){
    if(-not (Test-Path -LiteralPath $path)){throw 'A required local project component is missing.'}
}
& $preliminary -Session $folder -Language $locale.Locale -NoBrowser | Out-Null
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
    $addition=New-Object 'System.Collections.Generic.List[string]'
    $addition.Add('# ADBMedic — '+$t.preliminary)
    $addition.Add('')
    $notice=if($locale.UI -eq 'ru'){'Приватный локальный отчёт. Для передачи в чат используйте только подготовленный ZIP.'}else{'Private local report. Share only the prepared ZIP with an AI chat.'}
    $addition.Add($notice)
    $addition.Add([IO.File]::ReadAllText((Join-Path $bundle.Directory 'REPORT.md')).Substring("# ADBMedic`n".Length))
    $addition.Add('## '+$t.findings)
    $addition.Add([IO.File]::ReadAllText($privateReport))
    [IO.File]::WriteAllText($privateReport,(($addition -join [Environment]::NewLine)+[Environment]::NewLine),[Text.Encoding]::UTF8)
    & $viewer -InputFile $privateReport -Language $locale.Locale | Out-Null
}
Write-Host $t.reportReady -ForegroundColor Green
if($bundle -and $bundle.Ready){
    Write-Host $t.shareInstruction
    Write-Host ''
    Write-Host $t.starterPrompt -ForegroundColor Cyan
    Write-Host $bundle.StarterPrompt
    Write-Host ''
}
if(-not $NoBrowser){
    while($true){
        Write-Host $t.openReport
        Write-Host $t.openReportFolder
        $choice=(Read-Host $t.reportChoice).Trim()
        if(-not $choice){break}
        try{
            switch($choice){
                '1'{Start-Process -FilePath (Join-Path $folder 'REPORT.html') | Out-Null}
                '2'{
                    $visibleFolder=if($bundle -and $bundle.Ready){$bundle.Directory}else{$folder}
                    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$visibleFolder+'"') | Out-Null
                }
                default{Write-Host $t.invalidReportChoice}
            }
        }catch{Write-Warning $t.openFailed}
    }
}
} catch {
    Write-Warning 'ADBMedic could not complete local diagnostics. Check ADB, USB authorization and local storage. Private error details are hidden.'
    exit 1
}
