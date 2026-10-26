[CmdletBinding()]
param(
    [string]$InstallRoot = '',
    [switch]$Launch,
    [ValidateSet('auto','codex','offline')][string]$Mode = 'offline',
    [string]$Language = 'auto',
    [switch]$SkipInstall,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# This repository is explicitly selected by the project owner.
$repository = 'andrewpozdnakov7-jpg/ADBMedic'
$files = @(
    'bootstrap.ps1', 'Start-ADBMedic.ps1', 'ADBMedic-Device.ps1',
    'ADBMedic-Locale.ps1', 'Package-ADBMedic.ps1', 'Analyze-ADBMedic.ps1',
    'Prepare-ADBMedicEvidence.ps1', 'Write-ADBMedicPreliminary.ps1',
    'Show-ADBMedicReport.ps1', 'README.md', 'LICENSE'
)

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'Local application storage is unavailable. Specify -InstallRoot.'
    }
    $InstallRoot = Join-Path $env:LOCALAPPDATA 'ADBMedic\app'
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
if (Test-Path -LiteralPath $InstallRoot) {
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container) -or
        ((Get-Item -LiteralPath $InstallRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The installation directory must be a regular directory.'
    }
}

Write-Host 'ADBMedic source: https://github.com/andrewpozdnakov7-jpg/ADBMedic'
Write-Host 'Downloads program source only. Diagnostic ZIP export and cloud analysis remain disabled.'
$answer = Read-Host 'Download and install ADBMedic from this repository? [y/N]'
if ($answer -notmatch '^(y|yes|да|д)$') {
    Write-Host 'Installation cancelled.'
    return
}

$stage = $null
$oldProtocol = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = $oldProtocol -bor [Net.SecurityProtocolType]::Tls12
    $commit = Invoke-RestMethod -Uri 'https://api.github.com/repos/andrewpozdnakov7-jpg/ADBMedic/commits/main' -Headers @{'User-Agent'='ADBMedic-Installer'}
    $revision = [string]$commit.sha
    if ($revision -cnotmatch '^[0-9a-f]{40}$') {
        throw 'Invalid source revision.'
    }
    [IO.Directory]::CreateDirectory($InstallRoot) | Out-Null
    $stage = Join-Path $InstallRoot ('staging-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    foreach ($name in $files) {
        $destination = Join-Path $stage $name
        $uri = 'https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/' + $revision + '/' + $name
        Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $destination | Out-Null
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or (Get-Item -LiteralPath $destination).Length -eq 0) {
            throw 'A required source file is unavailable.'
        }
        if ([string]::IsNullOrWhiteSpace([IO.File]::ReadAllText($destination))) {
            throw 'A required source file has no text content.'
        }
        if ($name.EndsWith('.ps1')) {
            $tokens = $null; $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($destination, [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count -gt 0) { throw 'Downloaded PowerShell source did not pass syntax validation.' }
        }
    }
    $installed = Join-Path $InstallRoot $revision
    if (Test-Path -LiteralPath $installed) {
        if (-not (Test-Path -LiteralPath $installed -PathType Container) -or
            ((Get-Item -LiteralPath $installed -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'The selected version directory is not a regular directory.'
        }
        foreach ($name in $files) {
            $existing = Join-Path $installed $name
            if (-not (Test-Path -LiteralPath $existing -PathType Leaf) -or
                ((Get-Item -LiteralPath $existing -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                (Get-FileHash -LiteralPath $existing -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath (Join-Path $stage $name) -Algorithm SHA256).Hash) {
                throw 'The existing installation differs from the selected source revision.'
            }
        }
    } else {
        [IO.Directory]::Move($stage, $installed)
        $stage = $null
    }
} catch {
    # Do not expose exception messages containing local paths or provider diagnostics.
    throw 'ADBMedic installation failed. Check repository availability, required files and local permissions. Existing versions were not overwritten.'
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $oldProtocol
    if ($stage -and [IO.Directory]::Exists($stage)) {
        try {
            $stagePath = [IO.Path]::GetFullPath($stage)
            $rootPrefix = $InstallRoot.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
            if (-not $stagePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
                [IO.Path]::GetFileName($stagePath) -notmatch '^staging-[0-9a-f]{32}$' -or
                ((Get-Item -LiteralPath $stagePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Invalid temporary installation cleanup target.'
            }
            [IO.Directory]::Delete($stagePath, $true)
        }
        catch { Write-Warning 'Could not remove the temporary source installation.' }
    }
}

Write-Host ('ADBMedic installed from revision ' + $revision + '.')
Write-Output ('app/' + $revision)
if ($Launch) {
    & (Join-Path $installed 'bootstrap.ps1') -Mode $Mode -Language $Language -SkipInstall:$SkipInstall -NoBrowser:$NoBrowser
}
