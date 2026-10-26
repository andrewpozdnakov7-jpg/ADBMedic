[CmdletBinding()]
param([string]$SourceRoot = '', [string]$OutputPath = '')
$ErrorActionPreference='Stop'
$stage=$null
try {
    if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot=Split-Path -Parent $PSScriptRoot }
    . (Join-Path $PSScriptRoot 'Privacy.Core.ps1')
    $SourceRoot=[IO.Path]::GetFullPath($SourceRoot).TrimEnd([char[]]'\/')
    if (-not $OutputPath) { $OutputPath=Join-Path $SourceRoot 'exports/ADBMedic-source.zip' }
    $OutputPath=[IO.Path]::GetFullPath($OutputPath)
    if (Test-Path -LiteralPath $OutputPath) { throw 'Output already exists.' }
    $findings=@(Invoke-PrivacyAudit $SourceRoot)
    if ($findings.Count) { $findings | Write-Output; throw 'Source audit failed.' }
    $allowed=@(Get-PrivacyManifest ([IO.File]::ReadAllBytes((Join-Path $SourceRoot 'source-manifest.json'))))
    $privateRoot=Join-Path $SourceRoot '.test-work'
    if ((Test-Path -LiteralPath $privateRoot) -and ((Get-Item -LiteralPath $privateRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Temporary root must not be a link.' }
    $stage=Join-Path $privateRoot ('archive-'+[guid]::NewGuid().ToString('N'))
    $copy=Join-Path $stage 'source'
    [IO.Directory]::CreateDirectory($copy) | Out-Null
    foreach ($name in $allowed) {
        $target=Join-Path $copy $name
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.File]::Copy((Join-Path $SourceRoot $name),$target)
    }
    $findings=@(Invoke-PrivacyAudit $copy)
    if ($findings.Count) { $findings | Write-Output; throw 'Staged source audit failed.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archivePath=Join-Path $stage 'source.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($copy,$archivePath)
    # Re-extract into an independent directory and repeat the audit.
    $unpacked=Join-Path $stage 'unpacked'
    [IO.Compression.ZipFile]::ExtractToDirectory($archivePath,$unpacked)
    $findings=@(Invoke-PrivacyAudit $unpacked)
    if ($findings.Count) { $findings | Write-Output; throw 'Archive audit failed.' }
    $unpackedFiles=@(Get-PrivacyTreeFiles $unpacked)
    if ($unpackedFiles.Count -ne $allowed.Count) { throw 'Archive entry count differs.' }
    foreach ($name in $allowed) {
        if ((Get-FileHash -LiteralPath (Join-Path $copy $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $unpacked $name)).Hash) { throw 'Archive content differs.' }
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath)) | Out-Null
    [IO.File]::Move($archivePath,$OutputPath)
    Write-Output 'Safe source archive: PASS'
} catch {
    Write-Output '[archive]:0 blocked-or-failed'
    exit 1
} finally {
    if ($stage -and [IO.Directory]::Exists($stage)) {
        $target=[IO.Path]::GetFullPath($stage)
        $prefix=[IO.Path]::GetFullPath((Join-Path $SourceRoot '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
        if ($target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($target) -match '^archive-[a-f0-9]{32}$' -and
            -not ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { [IO.Directory]::Delete($target,$true) }
    }
}
