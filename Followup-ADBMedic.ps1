[CmdletBinding()]
param([string]$Case='',[string]$Request='',[string]$Language='auto')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$locale=Resolve-ADBMedicLanguage -Language $Language
try{
    . (Join-Path $PSScriptRoot 'ADBMedic-Interactive.ps1')
    if(-not $Case){
        $choice=Select-ADBMedicResumeCase (Join-Path $env:LOCALAPPDATA 'ADBMedic\data') $locale.UI
        if($choice.Action -ne 'resume'){return}
        Show-ADBMedicCaseMenu $choice.Case.Directory $choice.Case.Bundle $locale.UI
        return
    }
    $Case=Assert-ADBMedicLocalDirectory $Case
    $state=Get-ADBMedicCaseState $Case
    if($Request){$imported=Read-ADBMedicRequestFile $Request $state.case_id}else{$imported=Import-ADBMedicInteractiveRequest $state.case_id $locale.UI}
    if(-not $imported){return}
    $bundle=Invoke-ADBMedicConfirmedFollowup $Case $imported $locale.UI
    if($bundle){Write-Host $bundle.ArchiveName;Write-Host (Get-ADBMedicInteractiveText $locale.UI).attach;Write-Host $bundle.StarterPrompt}
}catch{Write-ADBMedicInteractiveError $_ $locale.UI;exit 1}