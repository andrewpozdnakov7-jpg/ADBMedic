[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$MessageFile)
$ErrorActionPreference='Stop'
try {
    $root=Split-Path -Parent $PSScriptRoot
    . (Join-Path $PSScriptRoot 'Privacy.Core.ps1')
    $findings=@(Get-PrivacyTextFindings (Get-PrivacyText ([IO.File]::ReadAllBytes($MessageFile))) '[commit-message]')
    foreach ($kind in @('GIT_AUTHOR_IDENT','GIT_COMMITTER_IDENT')) {
        $identity = Get-PrivacyText (Invoke-PrivacyGit $root @('var',$kind))
        if ($identity -cnotmatch '^Andrew <andrewpozdnakov7@gmail\.com> \d+ [+-]\d{4}\s*$') { $findings += '[commit-metadata]:0 unapproved-author' }
    }
    if ($findings.Count) { $findings | Sort-Object -Unique | Write-Output; exit 1 }
    exit 0
} catch { Write-Output '[commit-message]:0 audit-failed-closed'; exit 2 }
