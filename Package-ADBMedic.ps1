[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Session,
    [string]$Language='auto',
    [switch]$PassThru
)
# Raw export stays blocked. The owner authorized a validated derived-facts ZIP.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
try{
    . (Join-Path $PSScriptRoot 'ADBMedic-SafeExport.ps1')
    $bundle=New-ADBMedicSafeBundle $Session $locale.UI
    if($PassThru){Write-Output $bundle}else{Write-Output $bundle.ArchiveName}
}catch{
    if($locale.UI -eq 'ru'){throw 'Безопасный ZIP не создан: данные отсутствуют, формат не поддерживается или проверка не пройдена. Не передавайте сырые логи или локальный отчёт.'}
    throw 'Safe ZIP was not created: measurements are missing, unsupported or failed validation. Do not share raw logs or the private local report.'
}
