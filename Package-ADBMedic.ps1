[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Session,[string]$Language='auto',[switch]$PassThru)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
try{
    . (Join-Path $PSScriptRoot 'ADBMedic-Handoff.ps1')
    $bundle=New-ADBMedicDiagnosticBundle $Session $locale.UI -AnswerLocale $locale.Locale
    if($PassThru){$bundle}else{$bundle.ArchiveName}
}catch{
    $message=if($locale.UI -eq 'ru'){'ZIP не создан: проверьте свободное место, доступ к файлам и наличие предыдущей папки exports. Исходные данные сохранены.'}else{'ZIP not created: check free space, file access and whether exports already exists. Original evidence is retained.'}
    throw ('[ADBMEDIC-EXPORT] '+$message)
}