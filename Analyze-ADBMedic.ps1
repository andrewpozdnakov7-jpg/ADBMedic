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
    Write-Warning 'Автоматический облачный анализ отключён. Если безопасный ADBMedic-report.zip подготовлен, прикрепите его в чат нейросети вручную. Никакие данные не отправлены.'
}else{
    Write-Warning 'Automatic cloud analysis is disabled. If a safe ADBMedic-report.zip was prepared, attach it to your AI chat manually. Nothing was uploaded.'
}
