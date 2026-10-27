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
    $bundle=New-ADBMedicDiagnosticBundle $Session $locale.UI
    if($PassThru){Write-Output $bundle}else{Write-Output $bundle.ArchiveName}
}catch{
    if($locale.UI -eq 'ru'){throw 'Диагностический ZIP не создан: отсутствует контекст, обнаружены возможные секреты или проверка не пройдена. Подробности остаются локальными.'}
    throw 'Diagnostic ZIP was not created: context is missing, possible secrets were found or validation failed. Details remain local.'
}
