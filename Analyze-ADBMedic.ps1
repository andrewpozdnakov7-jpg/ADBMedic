[CmdletBinding()]
param(
    [string]$Session,
    [string]$Language='auto',
    [switch]$SkipInstall,
    [switch]$NoBrowser
)
# SECURITY HOLD: no Codex/API connection from this revision.
# User confirmation alone cannot guarantee raw diagnostic data were anonymized.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
if($locale.UI -eq 'ru'){
    Write-Warning 'Облачный анализ временно отключён: данные ещё не прошли обязательную анонимизацию (TASK-002). Никакие данные не отправлены.'
}else{
    Write-Warning 'Cloud analysis is temporarily disabled: diagnostic data have not passed required anonymization (TASK-002). Nothing was uploaded.'
}
