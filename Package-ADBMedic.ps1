[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Session,
    [string]$Language='auto',
    [switch]$PassThru
)
# The user manually shares diagnostic evidence with their chosen AI.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
try{
    . (Join-Path $PSScriptRoot 'ADBMedic-SafeExport.ps1')
    . (Join-Path $PSScriptRoot 'ADBMedic-Handoff.ps1')
    $bundle=New-ADBMedicDiagnosticBundle $Session $locale.UI -AnswerLocale $locale.Locale
    if($PassThru){Write-Output $bundle}else{Write-Output $bundle.ArchiveName}
}catch{
    $reason=[string]$_.Exception.Data['ADBMedicReason']
    $file=[string]$_.Exception.Data['ADBMedicFile']
    if($file -cnotin @('profile.json','symptom.txt','collection.json','cpu.txt','top.txt','battery.txt','battery-state.txt','power.txt','thermal.txt','camera.txt','sensors.txt','packages.txt','alarms.txt','jobs.txt','deviceidle.txt')){$file='input'}
    $ru=$locale.UI -eq 'ru'
    $message=switch($reason){
        'input-too-large' {if($ru){'ZIP не создан: '+$file+' превышает лимит 64 МиБ. Исходные данные сохранены.'}else{'ZIP not created: '+$file+' exceeds the 64 MiB file limit. Original data is retained.'}}
        'total-too-large' {if($ru){'ZIP не создан: суммарный объём диагностики превышает 128 МиБ. Исходные данные сохранены.'}else{'ZIP not created: diagnostic evidence exceeds the 128 MiB total limit. Original data is retained.'}}
        'secret' {if($ru){'ZIP не создан: в '+$file+' найден возможный секрет. Проверьте этот файл локально; значение скрыто.'}else{'ZIP not created: possible secret in '+$file+'. Review that file locally; the value is hidden.'}}
        'invalid-text' {if($ru){'ZIP не создан: '+$file+' содержит двоичные данные или неподдерживаемую кодировку.'}else{'ZIP not created: '+$file+' contains binary data or unsupported text encoding.'}}
        'unsafe-input' {if($ru){'ZIP не создан: '+$file+' является ссылкой вместо обычного файла.'}else{'ZIP not created: '+$file+' is a link rather than a regular file.'}}
        'missing-context' {if($ru){'ZIP не создан: отсутствует profile.json или symptom.txt. Нужна папка полной сессии.'}else{'ZIP not created: profile.json or symptom.txt is missing. Select a complete session folder.'}}
        'existing-export' {if($ru){'Папка exports уже существует. Существующие данные не перезаписаны.'}else{'The exports folder already exists. Existing data was not overwritten.'}}
        default {if($ru){'Диагностический ZIP не создан: проверка формата или упаковки не пройдена. Подробности остаются локальными.'}else{'Diagnostic ZIP was not created: format or archive validation failed. Details remain local.'}}
    }
    throw ('[ADBMEDIC-EXPORT] '+$message)
}
