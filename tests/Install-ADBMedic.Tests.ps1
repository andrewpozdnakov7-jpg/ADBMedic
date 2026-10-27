$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'Install-ADBMedic.ps1'
$testRoot = Join-Path $root ('.test-work\installer-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$installerTestState = [pscustomobject]@{Revision=('a' * 40); Answer='y'; Scenario='success'; Downloads=@(); MetadataReads=0; RestApiCalls=0; Passed=0}

function Assert([bool]$Condition, [string]$Description) {
    if (-not $Condition) { throw ('Installer test failed: ' + $Description) }
    $installerTestState.Passed++
}
function Read-Host { param($Prompt) return $installerTestState.Answer }
function Invoke-RestMethod {
    $installerTestState.RestApiCalls++
    throw 'REST API must not be needed for source installation.'
}
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec)
    if (-not $OutFile) {
        $installerTestState.MetadataReads++
        if ($Uri -cne 'https://github.com/andrewpozdnakov7-jpg/ADBMedic.git/info/refs?service=git-upload-pack') { throw 'Unexpected source reference endpoint.' }
        if ($installerTestState.Scenario -eq 'metadata-failure') { throw 'TEST_REFERENCE_UNAVAILABLE' }
        $advertisedRevision=$installerTestState.Revision
        if ($installerTestState.Scenario -eq 'bad-revision') { $advertisedRevision='TEST_INVALID' }
        $packet=$advertisedRevision+" refs/heads/main`n"
        $content="001e# service=git-upload-pack`n0000"+('{0:x4}' -f (4+$packet.Length))+$packet+'0000'
        return [pscustomobject]@{RawContentStream=([IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes($content),$false))}
    }
    $installerTestState.Downloads += $Uri
    if ($installerTestState.Scenario -eq 'network-failure') { throw 'TEST_PRIVATE_PROVIDER_DETAIL' }
    $name = Split-Path -Leaf $OutFile
    if ($name -eq 'bootstrap.ps1') {
        $content = @'
param($Mode, $Language, [switch]$SkipInstall, [switch]$NoBrowser)
[pscustomobject]@{Type='SyntheticLaunch'; Mode=$Mode; Language=$Language; SkipInstall=[bool]$SkipInstall; NoBrowser=[bool]$NoBrowser}
'@
    } elseif ($name.EndsWith('.ps1')) { $content = '# TEST_SYNTHETIC_SOURCE' }
    else { $content = 'TEST_SYNTHETIC_DOCUMENT' }
    if ($installerTestState.Scenario -eq 'invalid-source' -and $name -eq 'Start-ADBMedic.ps1') { $content = 'param(' }
    if ($installerTestState.Scenario -eq 'empty-source' -and $name -eq 'README.md') { $content = '' }
    [IO.File]::WriteAllText($OutFile, $content, [Text.Encoding]::UTF8)
}
function ExpectBlocked([string]$Scenario) {
    $installerTestState.Scenario = $Scenario
    $caseRoot = Join-Path $testRoot $Scenario
    $blocked = $false
    try { & $installer -InstallRoot $caseRoot -Launch | Out-Null }
    catch {
        $blocked = $true
        Assert (-not $_.Exception.Message.Contains('TEST_PRIVATE_PROVIDER_DETAIL')) 'provider error is hidden'
        Assert (-not $_.Exception.Message.Contains($testRoot)) 'local path is hidden'
    }
    Assert $blocked ($Scenario + ' is rejected')
    Assert (-not (Test-Path -LiteralPath (Join-Path $caseRoot $installerTestState.Revision))) ($Scenario + ' is not activated')
    Assert (@(Get-ChildItem -LiteralPath $caseRoot -Filter 'staging-*' -ErrorAction SilentlyContinue).Count -eq 0) ($Scenario + ' staging is removed')
}

try {
    $installRoot = Join-Path $testRoot 'TEST установка с пробелами'
    $installerTestState.Answer = 'n'
    & $installer -InstallRoot $installRoot -Launch | Out-Null
    Assert ($installerTestState.MetadataReads -eq 0 -and $installerTestState.Downloads.Count -eq 0) 'decline makes no requests'
    Assert (-not (Test-Path -LiteralPath $installRoot)) 'decline writes no installation'
    $installerTestState.Answer = 'y'
    # Match the README invocation: installer runs as a downloaded scriptblock.
    $block = [scriptblock]::Create([IO.File]::ReadAllText($installer).TrimStart([char]0xFEFF))
    $result = @(& $block -InstallRoot $installRoot -Launch -Language 'ru-RU' -SkipInstall -NoBrowser)
    $launches = @($result | Where-Object { $_.Type -eq 'SyntheticLaunch' })
    Assert ($launches.Count -eq 1) 'downloaded scriptblock launches exactly once'
    Assert ($launches[0].Mode -eq 'offline' -and $launches[0].Language -eq 'ru-RU') 'safe default and language are forwarded'
    Assert ($launches[0].SkipInstall -and $launches[0].NoBrowser) 'launch switches are forwarded'
    $installed = Join-Path $installRoot $installerTestState.Revision
    Assert ((Get-ChildItem -LiteralPath $installed -File).Count -eq 11) 'only allowlisted source files are installed'
    Assert ($installerTestState.Downloads.Count -eq 11) 'expected source request count'
    Assert ($installerTestState.MetadataReads -eq 1 -and $installerTestState.RestApiCalls -eq 0) 'installation resolves the source revision without REST API quota'
    Assert (@($installerTestState.Downloads | Where-Object { $_ -notmatch ('^https://raw\.githubusercontent\.com/andrewpozdnakov7-jpg/ADBMedic/' + $installerTestState.Revision + '/[^/]+$') }).Count -eq 0) 'all files use one pinned source revision'

    $result = @(& $installer -InstallRoot $installRoot)
    Assert (@($result | Where-Object { $_.Type -eq 'SyntheticLaunch' }).Count -eq 0) 'installation without Launch does not run the application'
    Assert (@(Get-ChildItem -LiteralPath $installRoot -Filter 'staging-*').Count -eq 0) 'repeat installation cleans staging'

    $edited = Join-Path $installed 'README.md'
    [IO.File]::WriteAllText($edited, 'TEST_LOCAL_EDIT')
    $blocked = $false
    try { & $installer -InstallRoot $installRoot -Launch | Out-Null } catch { $blocked = $true }
    Assert $blocked 'modified existing version is rejected'
    Assert ([IO.File]::ReadAllText($edited) -eq 'TEST_LOCAL_EDIT') 'local edits are preserved'

    ExpectBlocked 'bad-revision'
    ExpectBlocked 'metadata-failure'
    ExpectBlocked 'network-failure'
    ExpectBlocked 'invalid-source'
    ExpectBlocked 'empty-source'
    $installerTestState.Scenario = 'success'
    # Test the real bootstrap with a synthetic launcher, never the real ADB entry point.
    $bootstrapRoot = Join-Path $testRoot 'TEST bootstrap'
    [IO.Directory]::CreateDirectory($bootstrapRoot) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'bootstrap.ps1') -Destination $bootstrapRoot
    foreach ($name in @('ADBMedic-Device.ps1','ADBMedic-Locale.ps1','Package-ADBMedic.ps1','Analyze-ADBMedic.ps1','Prepare-ADBMedicEvidence.ps1','Write-ADBMedicPreliminary.ps1','Show-ADBMedicReport.ps1')) {
        [IO.File]::WriteAllText((Join-Path $bootstrapRoot $name), '# TEST_SYNTHETIC_SOURCE')
    }
    Copy-Item -LiteralPath (Join-Path $installed 'bootstrap.ps1') -Destination (Join-Path $bootstrapRoot 'Start-ADBMedic.ps1')
    $result = @(& (Join-Path $bootstrapRoot 'bootstrap.ps1') -Mode offline -Language 'en-US' -SkipInstall -NoBrowser)
    Assert ($result.Count -eq 1 -and $result[0].NoBrowser -and $result[0].SkipInstall -and $result[0].Language -eq 'en-US') 'real bootstrap forwards arguments'
    $result=@(& (Join-Path $bootstrapRoot 'bootstrap.ps1'))
    Assert ($result.Count -eq 1 -and $result[0].Mode -eq 'offline') 'bootstrap without parameters selects the available local workflow'
    Assert ($result[0].Language -eq 'auto') 'bootstrap without parameters selects language automatically'
    Write-Host ('Offline installer tests: PASS (' + $installerTestState.Passed + ' assertions).')
} finally {
    $resolvedRoot = [IO.Path]::GetFullPath((Join-Path $root '.test-work')) + [IO.Path]::DirectorySeparatorChar
    $resolvedTest = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolvedTest.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe synthetic test cleanup target.' }
    if ([IO.Directory]::Exists($resolvedTest)) { [IO.Directory]::Delete($resolvedTest, $true) }
}
