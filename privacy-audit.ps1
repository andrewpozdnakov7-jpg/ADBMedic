[CmdletBinding()]
param(
    [string]$SourceRoot = '',
    [ValidateSet('Worktree','Staged','History')][string]$Mode = 'Worktree',
    [string]$Revision = 'HEAD'
)
$ErrorActionPreference = 'Stop'
try {
    if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot=$PSScriptRoot }
    . (Join-Path $PSScriptRoot 'scripts/Privacy.Core.ps1')
    $findings = @(Invoke-PrivacyAudit -Root $SourceRoot -Mode $Mode -Revision $Revision)
    if ($findings.Count) { $findings | Sort-Object -Unique | Write-Output; exit 1 }
    Write-Output ('Privacy audit ' + $Mode + ': PASS')
    exit 0
} catch {
    $failureType=$_.Exception.GetType().Name
    if ($_.Exception.InnerException) { $failureType+='-'+$_.Exception.InnerException.GetType().Name }
    $failureLine=0
    if ($_.ScriptStackTrace -match ': (?:line|строка) (\d+)') { $failureLine=[int]$Matches[1] }
    Write-Output ('[audit]:'+$failureLine+' audit-failed-closed-'+$failureType)
    exit 2
}
