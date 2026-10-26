$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts/Privacy.Core.ps1')
$testRoot=Join-Path $root ('.test-work/privacy-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$privacyTestState=@{Passed=0}
function Assert([bool]$Condition,[string]$Description) {
    if (-not $Condition) { throw ('Privacy test failed: '+$Description) }
    $privacyTestState.Passed++
}
function Write-TestText([string]$Path,[string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path,$Text,([Text.UTF8Encoding]::new($true)))
}
function New-Fixture([string]$Name) {
    $fixture=Join-Path $testRoot $Name
    Write-TestText (Join-Path $fixture 'README.md') 'Synthetic source.'
    Write-TestText (Join-Path $fixture 'source-manifest.json') (@{files=@('README.md','source-manifest.json')} | ConvertTo-Json)
    return $fixture
}
function Git([string]$Path,[string[]]$Arguments) {
    try { return (Get-PrivacyText (Invoke-PrivacyGit $Path $Arguments)).Trim() }
    catch { throw ('Synthetic Git operation failed: '+$Arguments[0]+'. '+$_.Exception.Message) }
}
try {
    $fixture=New-Fixture 'TEST проверка с пробелами'
    Assert (@(Invoke-PrivacyAudit $fixture).Count -eq 0) 'clean source passes'
    $cases=@(
        @{Category='home-path'; Value=('C:'+[char]92+'Users'+[char]92+'TEST_PRIVATE'+[char]92+'file')},
        @{Category='home-path'; Value=('/ho'+'me/TEST_PRIVATE/file')},
        @{Category='email'; Value=('TEST_PERSON'+'@privacy-test.invalid')},
        @{Category='ip-address'; Value=(@(192,0,2,33)-join '.')},
        @{Category='mac-address'; Value=(@('02','00','00','00','00','33')-join ':')},
        @{Category='token'; Value=('gh'+'p_'+('A'*36))},
        @{Category='private-key'; Value=(('-'*5)+'BEGIN '+'PRIVATE KEY'+('-'*5))},
        @{Category='private-key'; Value=(('-'*5)+'BEGIN '+'CERTIFICATE'+('-'*5))},
        @{Category='credential-assignment'; Value=('api'+'_key = '+[char]34+'TEST_SECRET'+[char]34)},
        @{Category='hardware-identifier'; Value=('android'+'_id = '+[char]34+'TEST_DEVICE'+[char]34)},
        @{Category='hardware-identifier'; Value=('user'+'name = '+[char]34+'TEST_PRIVATE'+[char]34)},
        @{Category='hardware-identifier'; Value=('A1'*32)},
        @{Category='hardware-identifier'; Value=(@('a1b2c3d4','a1b2','a1b2','a1b2','a1b2c3d4e5f6')-join '-')},
        @{Category='device-fingerprint'; Value=('TEST_VENDOR/TEST_PRODUCT/TEST_DEVICE'+':14/TEST_BUILD/123:user/release-keys')},
        @{Category='diagnostic-content'; Value=('DUMP '+'OF SERVICE TEST_SERVICE:')},
        @{Category='url'; Value=('https'+ '://privacy-test.invalid/source')}
    )
    foreach ($case in $cases) {
        Write-TestText (Join-Path $fixture 'README.md') $case.Value
        $findings=@(Invoke-PrivacyAudit $fixture)
        Assert (@($findings | Where-Object { $_ -match (' '+$case.Category+'$') }).Count -gt 0) ($case.Category+' is detected')
        Assert (-not (($findings -join "`n").Contains($case.Value))) 'matched content is never printed'
    }
    Write-TestText (Join-Path $fixture 'README.md') 'andrewpozdnakov7@gmail.com'
    Assert (@(Invoke-PrivacyAudit $fixture).Count -eq 0) 'exact public email is allowed'
    Write-TestText (Join-Path $fixture 'README.md') ('prefix'+'andrewpozdnakov7@gmail.com')
    Assert (@(Invoke-PrivacyAudit $fixture).Count -gt 0) 'email allowlist does not allow prefixes'
    Write-TestText (Join-Path $fixture 'README.md') 'https://github.com/andrewpozdnakov7-jpg/ADBMedic'
    Assert (@(Invoke-PrivacyAudit $fixture).Count -eq 0) 'canonical repository reference is allowed'
    Write-TestText (Join-Path $fixture 'README.md') ('https://github.com/andrewpozdnakov7-jpg/ADBMedic'+'?private=TEST_PRIVATE')
    Assert (@(Invoke-PrivacyAudit $fixture).Count -gt 0) 'URL query is not hidden by the allowlist'
    Write-TestText (Join-Path $fixture 'README.md') 'Synthetic source.'

    $private=Join-Path $fixture 'nested/data/TEST_PRIVATE.log'
    Write-TestText $private $cases[5].Value
    Assert (@(Invoke-PrivacyAudit $fixture).Count -eq 0) 'private data is excluded from source traversal'
    $unknown=Join-Path $fixture ('TEST_PERSON'+'@'+'privacy-test.invalid.md')
    Write-TestText $unknown 'Synthetic source.'
    $findings=@(Invoke-PrivacyAudit $fixture)
    Assert ($findings.Count -gt 0 -and -not (($findings -join "`n").Contains([IO.Path]::GetFileName($unknown)))) 'unapproved filename is blocked without disclosure'
    [IO.File]::Delete($unknown)
    [IO.File]::WriteAllBytes((Join-Path $fixture 'README.md'),[byte[]]@(0,1,2))
    Assert (@(@(Invoke-PrivacyAudit $fixture) -match 'binary-or-invalid-utf8').Count -gt 0) 'binary source is rejected'
    Write-TestText (Join-Path $fixture 'README.md') 'Synthetic source.'

    $external=New-Fixture 'TEST external synthetic'
    $link=Join-Path $fixture 'linked'
    New-Item -ItemType Junction -Path $link -Target $external | Out-Null
    Assert (@(Invoke-PrivacyAudit $fixture).Count -gt 0) 'directory junction is rejected without traversal'
    [IO.Directory]::Delete($link)

    $audit=Join-Path $root 'privacy-audit.ps1'
    $log=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -File $audit 2>&1)
    Assert ($LASTEXITCODE -eq 0) 'CLI resolves its default source root without parameter-default scope errors'
    Write-TestText (Join-Path $fixture 'README.md') $cases[5].Value
    $log=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -File $audit -SourceRoot $fixture 2>&1)
    Assert ($LASTEXITCODE -ne 0) 'CLI returns nonzero for findings'
    Assert (-not (($log -join "`n").Contains($cases[5].Value))) 'CLI does not print synthetic secret'
    Write-TestText (Join-Path $fixture 'README.md') 'Synthetic source.'

    $archive=Join-Path $testRoot 'source.zip'
    $log=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Build-SafeSourceArchive.ps1') -SourceRoot $fixture -OutputPath $archive 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archive)) 'safe source archive passes'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($archive)
    try { Assert ($zip.Entries.Count -eq 2 -and @($zip.Entries | Where-Object { $_.FullName -match 'data|private|\.git' }).Count -eq 0) 'archive contains only manifest files' }
    finally { $zip.Dispose() }
    $fullArchive=Join-Path $testRoot 'full-source.zip'
    $log=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Build-SafeSourceArchive.ps1') -OutputPath $fullArchive 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $fullArchive)) 'archive resolves default source root and verifies the full source manifest'
    Write-TestText (Join-Path $fixture 'README.md') $cases[5].Value
    $blockedArchive=Join-Path $testRoot 'blocked.zip'
    $log=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Build-SafeSourceArchive.ps1') -SourceRoot $fixture -OutputPath $blockedArchive 2>&1)
    Assert ($LASTEXITCODE -ne 0 -and -not (Test-Path -LiteralPath $blockedArchive)) 'source findings block archive creation'

    $gitRoot=New-Fixture 'TEST git'
    $gitFiles=@('README.md','source-manifest.json','.gitignore','privacy-audit.ps1','scripts/Privacy.Core.ps1','scripts/Test-CommitMessage.ps1','.githooks/pre-commit','.githooks/commit-msg','.githooks/pre-push')
    foreach ($name in $gitFiles | Where-Object { $_ -notin @('README.md','source-manifest.json') }) {
        $target=Join-Path $gitRoot $name
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.File]::Copy((Join-Path $root $name),$target)
    }
    Write-TestText (Join-Path $gitRoot 'source-manifest.json') (@{files=$gitFiles} | ConvertTo-Json)
    $null=Git $gitRoot @('init','--initial-branch=main')
    $null=Git $gitRoot @('config','user.name','Andrew')
    $null=Git $gitRoot @('config','user.email','andrewpozdnakov7@gmail.com')
    $null=Git $gitRoot @('config','core.hooksPath','.githooks')
    $null=Git $gitRoot @('add','--all')
    Assert (@(Invoke-PrivacyAudit $gitRoot 'Staged').Count -eq 0) 'clean staged snapshot passes'
    Write-TestText (Join-Path $gitRoot 'README.md') $cases[5].Value
    $null=Git $gitRoot @('add','README.md')
    Assert (@(@(Invoke-PrivacyAudit $gitRoot 'Staged') -match 'token').Count -gt 0) 'unsafe history fixture has a staged synthetic token'
    Write-TestText (Join-Path $gitRoot 'README.md') 'Synthetic source.'
    Assert (@(Invoke-PrivacyAudit $gitRoot 'Staged').Count -gt 0) 'staged secret is detected after worktree cleanup'
    $blocked=$false
    try { $null=Git $gitRoot @('commit','-m','Synthetic blocked fixture') } catch { $blocked=$true }
    Assert $blocked 'real pre-commit hook blocks staged secret'
    $null=Git $gitRoot @('add','README.md')
    $null=Git $gitRoot @('commit','-m','Synthetic clean fixture')
    Assert (@(Invoke-PrivacyAudit $gitRoot 'History').Count -eq 0) 'clean history and metadata pass'

    $privateFile=Join-Path $gitRoot 'nested/data/TEST_SIGNING.keystore'
    Write-TestText $privateFile 'TEST_SYNTHETIC_NOT_A_REAL_KEY'
    $null=Git $gitRoot @('add','-f','nested/data/TEST_SIGNING.keystore')
    Assert (@(Invoke-PrivacyAudit $gitRoot 'Staged').Count -gt 0) 'force-added private signing artifact is rejected'
    $null=Git $gitRoot @('rm','--cached','nested/data/TEST_SIGNING.keystore')

    $linkText=Join-Path $testRoot 'TEST_link_target.txt'
    Write-TestText $linkText 'TEST_EXTERNAL_TARGET'
    $blob=Git $gitRoot @('hash-object','-w',$linkText)
    $null=Git $gitRoot @('update-index','--add','--cacheinfo',('120000,'+$blob+',README.md'))
    Assert (@(@(Invoke-PrivacyAudit $gitRoot 'Staged') -match 'link-or-special-file').Count -gt 0) 'staged symlink is rejected'
    $cleanBlob=Git $gitRoot @('hash-object','-w','README.md')
    $null=Git $gitRoot @('update-index','--add','--cacheinfo',('100644,'+$cleanBlob+',README.md'))

    # Construct unreachable synthetic history with Git plumbing, without disabling hooks.
    $cleanTree=Git $gitRoot @('rev-parse','HEAD^{tree}')
    Write-TestText (Join-Path $gitRoot 'README.md') $cases[5].Value
    $null=Git $gitRoot @('add','README.md')
    $unsafeTree=Git $gitRoot @('write-tree')
    $parent=Git $gitRoot @('rev-parse','HEAD')
    $unsafeCommit=Git $gitRoot @('commit-tree',$unsafeTree,'-p',$parent,'-m','Synthetic unsafe ancestor')
    Assert ((Git $gitRoot @('show',($unsafeCommit+':README.md'))).TrimStart([char]0xFEFF) -eq $cases[5].Value) 'unsafe ancestor really contains the synthetic token'
    $cleanTip=Git $gitRoot @('commit-tree',$cleanTree,'-p',$unsafeCommit,'-m','Synthetic clean tip')
    Write-TestText (Join-Path $gitRoot 'README.md') 'Synthetic source.'
    $null=Git $gitRoot @('add','README.md')
    $historyFindings=@(Invoke-PrivacyAudit $gitRoot 'History' $cleanTip)
    Assert (@($historyFindings -match 'token').Count -gt 0) ('unsafe ancestor is detected under a clean tip; categories='+($historyFindings -join ','))
    $bare=Join-Path $testRoot 'TEST-remote.git'
    $null=Git $testRoot @('init','--bare',$bare)
    $blocked=$false
    try { $null=Git $gitRoot @('push',$bare,($cleanTip+':refs/heads/test-negative')) } catch { $blocked=$true }
    Assert $blocked 'real pre-push hook blocks outgoing unsafe history'
    $null=Git $gitRoot @('push',$bare,'HEAD:refs/heads/test-clean')
    Assert ((Git $bare @('rev-parse','refs/heads/test-clean')) -eq $parent) 'real pre-push hook permits clean history'
    Write-Host ('Offline privacy tests: PASS ('+$privacyTestState.Passed+' assertions).')
} finally {
    $target=[IO.Path]::GetFullPath($testRoot)
    $prefix=[IO.Path]::GetFullPath((Join-Path $root '.test-work')).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    if (-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup target.' }
    function Remove-SyntheticDirectory([string]$Directory) {
        foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                if ($item.PSIsContainer) { [IO.Directory]::Delete($item.FullName) } else { [IO.File]::Delete($item.FullName) }
            } elseif ($item.PSIsContainer) { Remove-SyntheticDirectory $item.FullName }
            else { [IO.File]::SetAttributes($item.FullName,[IO.FileAttributes]::Normal); [IO.File]::Delete($item.FullName) }
        }
        [IO.Directory]::Delete($Directory)
    }
    if ([IO.Directory]::Exists($target)) { Remove-SyntheticDirectory $target }
}
