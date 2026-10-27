[CmdletBinding()]
param(
    [ValidateSet('auto','codex','offline')][string]$Mode='offline',
    [string]$Language='auto',
    [switch]$SkipInstall,
    [switch]$NoBrowser
)
$ErrorActionPreference='Stop'
# Local launcher. Install-ADBMedic.ps1 handles explicit repository installation.
$modules=@(
    'Start-ADBMedic.ps1', 'ADBMedic-Device.ps1',
    'ADBMedic-Locale.ps1', 'Package-ADBMedic.ps1',
    'Analyze-ADBMedic.ps1', 'Prepare-ADBMedicEvidence.ps1',
    'Write-ADBMedicPreliminary.ps1', 'Show-ADBMedicReport.ps1'
)
foreach($name in $modules){
    $path=Join-Path $PSScriptRoot $name
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){
        throw ('Missing local project component: '+$name)
    }
}
& (Join-Path $PSScriptRoot 'Start-ADBMedic.ps1') -Mode $Mode -Language $Language -SkipInstall:$SkipInstall -NoBrowser:$NoBrowser
