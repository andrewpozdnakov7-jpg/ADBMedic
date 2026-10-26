[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try {
    $root = Split-Path -Parent $PSScriptRoot
    . (Join-Path $PSScriptRoot 'Privacy.Core.ps1')
    $null = Invoke-PrivacyGit $root @('config','--local','core.hooksPath','.githooks')
    Write-Output 'Local privacy hooks installed. They protect commits and outgoing branch history.'
} catch { Write-Output '[hooks]:0 installation-failed'; exit 1 }
