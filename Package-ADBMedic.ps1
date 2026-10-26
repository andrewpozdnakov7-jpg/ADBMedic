[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Session,
    [string]$Language='auto'
)
# SECURITY HOLD: re-enable only after TASK-001/TASK-002 privacy acceptance.
# Do not copy, zip, transform or upload raw diagnostics here.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
if($locale.UI -eq 'ru'){
    throw 'Экспорт ZIP отключён: исходные Android-дампы могут содержать персональные данные. Требуется проверенная очистка (TASK-002). Исходные измерения сохранены локально.'
}
throw 'ZIP export is disabled: raw Android dumps may contain personal data. A verified sanitizer is required (TASK-002). Original evidence remains local.'
