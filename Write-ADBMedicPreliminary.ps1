[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Session,
    [string]$Language='auto',
    [switch]$NoBrowser
)
$ErrorActionPreference='Stop'
try {
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$folder=(Resolve-Path -LiteralPath $Session).Path
$locale=Resolve-ADBMedicLanguage -Language $Language -Session $folder
$t=Get-ADBMedicText -UI $locale.UI

$profilePath=Join-Path $folder 'profile.json'
$profile=$null
if(Test-Path -LiteralPath $profilePath){
    try {$profile=Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json} catch {}
}
$model=if($profile -and $profile.model){[string]$profile.model}else{'Unknown'}
$android=if($profile -and $profile.android){[string]$profile.android}else{'Unknown'}
$stamp=if($profile -and $profile.captured){[string]$profile.captured}else{(Get-Date).ToString('o')}
$symptom=$t.noSymptom
$sp=Join-Path $folder 'symptom.txt'
if(Test-Path -LiteralPath $sp){$txt=[IO.File]::ReadAllText($sp,[Text.Encoding]::UTF8).Trim();if($txt){$symptom=$txt}}
$symptom=($symptom -replace '[\r\n|]', ' ').Trim()
if($symptom.Length -gt 350){$symptom=$symptom.Substring(0,350)}

$files=@('cpu.txt','top.txt','battery.txt','power.txt','thermal.txt','camera.txt','sensors.txt','build.txt')
$rows=New-Object System.Collections.Generic.List[string]
foreach($name in $files){
    $path=Join-Path $folder $name
    $label=if($locale.UI -eq 'ru'){'Собран'}else{'Collected'}
    $bytes=0
    if(-not (Test-Path -LiteralPath $path)){$label=if($locale.UI -eq 'ru'){'Отсутствует'}else{'Missing'}}
    else{
        $bytes=(Get-Item -LiteralPath $path).Length
        if($bytes -eq 0){$label=if($locale.UI -eq 'ru'){'Пустой'}else{'Empty'}}
        else{
            $first=Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction SilentlyContinue | Out-String
            if($first -match '(Command failed|Capture failed)'){$label=if($locale.UI -eq 'ru'){'Ошибка сбора'}else{'Capture error'}}
        }
    }
    $rows.Add('| '+$name+' | '+$label+' | '+$bytes+' |')
}
$cpuLine=''
$topPath=Join-Path $folder 'top.txt'
if(Test-Path -LiteralPath $topPath){
    foreach($line in [IO.File]::ReadAllLines($topPath,[Text.Encoding]::UTF8)){
        if($line -match '^\s*\d+%cpu\s+'){$cpuLine=$line.Trim()}
    }
}
if($cpuLine.Length -gt 250){$cpuLine=$cpuLine.Substring(0,250)}
$cpuLine=$cpuLine.Replace('|','/')
if(-not $cpuLine){$cpuLine=$t.none}

$md=New-Object System.Collections.Generic.List[string]
$md.Add('# ADBMedic — '+$t.preliminary)
$md.Add('')
$md.Add('**'+$t.preNotice+'**')
$md.Add('')
$md.Add('## '+$t.short)
if($locale.UI -eq 'ru'){
    $md.Add('Измерения собраны локально. Автоматический анализ первопричины не выполнен.')
    $md.Add('')
    $md.Add('**Симптом:** '+$symptom)
    $md.Add('**Устройство:** '+$model+' / Android '+$android)
    $md.Add('**Дата сбора:** '+$stamp)
    $md.Add('**Язык отчёта:** '+$locale.Locale)
}else{
    $md.Add('Measurements were collected locally. No automated root-cause analysis has been performed.')
    $md.Add('')
    $md.Add('**Symptom:** '+$symptom)
    $md.Add('**Device:** '+$model+' / Android '+$android)
    $md.Add('**Capture time:** '+$stamp)
    $md.Add('**Report language:** '+$locale.Locale)
}
$md.Add('')
$md.Add('## '+$t.findings)
if($locale.UI -eq 'ru'){
    $md.Add('| Файл | Результат | Размер, байт |')
}else{
    $md.Add('| File | Status | Bytes |')
}
$md.Add('| --- | --- | --- |')
foreach($r in $rows){$md.Add($r)}
$md.Add('')
if($locale.UI -eq 'ru'){
    $md.Add('**Последняя строка общей загрузки CPU из top.txt** (без интерпретации):')
}else{
    $md.Add('**Last system-wide CPU header from top.txt** (not interpreted):')
}
$md.Add('')
$md.Add($cpuLine)
$md.Add('')
$md.Add('## '+$t.actions)
if($locale.UI -eq 'ru'){
    $md.Add('1. Изучить локальный отчёт и состояние собранных файлов.')
    $md.Add('2. Хранить сырые диагностические данные только локально; не загружать их в облако или GitHub.')
    $md.Add('3. Экспорт ZIP и облачный анализ недоступны до реализации проверенной очистки данных.')
}else{
    $md.Add('1. Review the local report and the status of collected files.')
    $md.Add('2. Keep raw diagnostics local; do not upload them to the cloud or GitHub.')
    $md.Add('3. ZIP export and cloud analysis are unavailable until verified data sanitization is implemented.')
}
$md.Add('')
$md.Add('## '+$t.confidence)
if($locale.UI -eq 'ru'){
    $md.Add('Статус: только сбор данных. Этот документ не подтверждает ни наличие, ни отсутствие повышенного расхода батареи. Экспорт ZIP и облачный анализ отключены.')
}else{
    $md.Add('Status: evidence collection only. This document neither confirms nor rules out abnormal battery drain. ZIP export and cloud analysis are disabled.')
}
$report=Join-Path $folder 'REPORT.md'
[IO.File]::WriteAllText($report,($md -join [Environment]::NewLine),[Text.Encoding]::UTF8)
$viewer=Join-Path $PSScriptRoot 'Show-ADBMedicReport.ps1'
if(Test-Path -LiteralPath $viewer){
    if($NoBrowser){& $viewer -InputFile $report -Language $locale.Locale | Out-Null}
    else{& $viewer -InputFile $report -Language $locale.Locale -Open | Out-Null}
}
Write-Output 'REPORT.md'

} catch { throw 'Local report or evidence generation failed. Check the selected local session without sharing private error details.' }
