# Shared offline source/index/history audit. Never print matched content.
function Invoke-PrivacyGit {
    param([string]$Root, [string[]]$Arguments)
    $all = @('-c', ('safe.directory=' + $Root.Replace('\','/')), '-C', $Root) + $Arguments
    foreach ($arg in $all) {
        if ($arg.Contains('"') -or $arg.Contains([char]0) -or $arg.Contains("`n") -or $arg.Contains("`r") -or $arg.EndsWith('\')) { throw 'Unsupported Git argument.' }
    }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = 'git'
    $info.Arguments = ($all | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $buffer = New-Object IO.MemoryStream
    try {
        [void]$process.Start()
        $errorRead = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $process.WaitForExit()
        $errorText=$errorRead.Result
        if ($process.ExitCode -ne 0) {
            $safeCategories=@([regex]::Matches(([Text.Encoding]::UTF8.GetString($buffer.ToArray())+"`n"+$errorText),'(?m):\d+ (audit-failed-closed(?:-[A-Za-z]+)*|file-not-allowlisted|missing-source|unapproved-author|home-path|email|url|token|hardware-identifier|binary-or-invalid-utf8)\s*$') | ForEach-Object { $_.Value.Trim() } | Sort-Object -Unique)
            $failureKinds=@(@('gpg','cannot spawn','cannot run','not found','execution policy','not digitally signed','bad interpreter','fatal','error') | Where-Object { $errorText -match [regex]::Escape($_) })
            throw ('Git operation failed ('+$process.ExitCode+'). Gate categories: '+($safeCategories -join ',')+'. Failure kinds: '+($failureKinds -join ','))
        }
        return ,$buffer.ToArray()
    } finally { $buffer.Dispose(); $process.Dispose() }
}

function Get-PrivacyText {
    param([byte[]]$Bytes, [switch]$AllowNull)
    if (-not $AllowNull -and $Bytes -contains 0) { throw 'Binary content.' }
    $decoder = New-Object Text.UTF8Encoding($false, $true)
    return $decoder.GetString($Bytes).TrimStart([char]0xFEFF)
}

function Get-PrivacyRules {
    return [ordered]@{
        'home-path' = '(?i)(?:[a-z]:[\\/]+(?:users|documents and settings)[\\/]+[^\s"''<>]+|/(?:home|Users)/[^/\s"''<>]+|\\\\[a-z0-9_-]+\\[^\s"'']+)'
        'email' = '(?i)(?<![\w.+-])[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}(?![\w.-])'
        'url' = '(?i)(?:https?|ssh|git)://[a-z0-9.-]+\.[a-z]{2,}(?=[:/\s"''<>)]|$)[^\s"''<>`]*'
        'ip-address' = '(?<![\w.])(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?![\w.])|(?i)(?<![\w:])(?:[a-f0-9]{1,4}:){3,7}[a-f0-9:]{1,4}(?![\w:])'
        'mac-address' = '(?i)(?<![\w:])(?:[a-f0-9]{2}[:-]){5}[a-f0-9]{2}(?![\w:])'
        'private-key' = '-----BEGIN (?:[A-Z0-9 ]*PRIVATE KEY|CERTIFICATE)-----'
        'token' = '(?i)\b(?:gh[pousr]_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,}|sk-(?:proj-)?[a-z0-9_-]{20,}|AKIA[A-Z0-9]{16})\b|\beyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\b'
        'credential-assignment' = '(?i)\b(?:password|passwd|pwd|api[_-]?key|access[_-]?token|client[_-]?secret|signing[_-]?password)\s*["'']?\s*[:=]\s*["''][^"''\r\n]{1,}["'']'
        'hardware-identifier' = '(?i)\b(?:serial(?:number)?|android[_ .-]?id|imei|imsi|device[_-]?id|hostname|username)\s*["'']?\s*[:=]\s*["''][^"''$\r\n]+["'']|(?<!\w)\d{14,16}(?!\w)|(?<!\w)[a-fA-F0-9]{16,}(?!\w)|(?i)(?<!\w)[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}(?!\w)'
        'device-fingerprint' = '(?i)\b[a-z0-9_.-]+/[a-z0-9_.-]+/[a-z0-9_.-]+:\d[^\s"'']*[:/](?:user|userdebug|eng)/(?:release|test)-keys\b'
        'diagnostic-content' = '(?im)^\s*(?:DUMP OF SERVICE|Build fingerprint:|------ SYSTEM LOG|----- pid \d+ at |backtrace:|BUG REPORT:)|\b(?:[a-z0-9_-]+\.)?(?:dynamic_report|bugreport)[-_]\d{4}'
        'retired-brand' = '(?i)droid' + 'sleuth'
    }
}

function Test-PrivacyAllowedValue {
    param([string]$Category, [string]$Value)
    if ($Category -eq 'email') {
        return $Value -ceq 'andrewpozdnakov7@gmail.com' -or $Value -cmatch '^[A-Za-z0-9._%+-]+@example\.(?:invalid|com)$'
    }
    if ($Category -eq 'url') {
        $Value=$Value.TrimEnd([char[]]'),.;]')
        return $Value -cmatch '^https://(?:github\.com/andrewpozdnakov7-jpg/ADBMedic(?:(?:\.git)?/?|/commit/[a-f0-9]{40}|/pull/[0-9]+)|api\.github\.com/repos/andrewpozdnakov7-jpg/ADBMedic/commits/main|raw\.githubusercontent\.com/andrewpozdnakov7-jpg/ADBMedic/(?:(?:main|[a-f0-9]{40})/[A-Za-z0-9_.-]+)?|developer\.android\.com/(?:studio/run/oem-usb|tools/releases/platform-tools)|dl\.google\.com/android/repository/platform-tools-latest-windows\.zip|example\.(?:invalid|com)(?:/[A-Za-z0-9_./-]*)?)$'
    }
    return $false
}

function Get-PrivacyTextFindings {
    param([string]$Text, [string]$Name)
    $rules = Get-PrivacyRules
    $lines = $Text -split '\r?\n'
    for ($index=0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        # Approved public URLs can legitimately contain a Git commit hash.
        foreach ($match in [regex]::Matches($line, $rules['url'])) {
            if (Test-PrivacyAllowedValue 'url' $match.Value) { $line = $line.Replace($match.Value, 'PUBLIC_PROJECT_REFERENCE') }
        }
        foreach ($category in $rules.Keys) {
            foreach ($match in [regex]::Matches($line, $rules[$category])) {
                if (-not (Test-PrivacyAllowedValue $category $match.Value)) {
                    '{0}:{1} {2}' -f $Name, ($index+1), $category
                    break
                }
            }
        }
    }
}

function Test-PrivacyForbiddenPath {
    param([string]$Name)
    return $Name -match '(?i)(^|/)(?:\.git|\.github|data|tools|sessions|reports|exports|private-local|raw|app|\.test-work|\.vscode|\.idea)(/|$)|(^|/)\.env(?:\.|$)|\.(?:zip|7z|tar|gz|log|tmp|bak|secret|token|exe|dll|apk|aab|bin|jks|keystore|p12|pfx|pem|key|cer|crt|der)$|(^|/)(?:profile|device|locale)\.json$|(^|/)(?:REPORT\.(?:html|md)|(?:bugreport|logcat).*|symptom\.txt|(?:cpu|top|battery|power|thermal|camera|sensors|build)\.txt)$'
}

function Get-PrivacyManifest {
    param([byte[]]$Bytes)
    $list = @((Get-PrivacyText $Bytes | ConvertFrom-Json).files)
    if ($list.Count -eq 0 -or $list -notcontains 'source-manifest.json') { throw 'Invalid source manifest.' }
    $seen = @{}
    foreach ($name in $list) {
        if ($name -isnot [string] -or $name -cnotmatch '^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*$' -or
            $name -match '(^|/)\.\.(/|$)' -or (Test-PrivacyForbiddenPath $name) -or $seen.ContainsKey($name.ToLowerInvariant())) {
            throw 'Invalid source manifest entry.'
        }
        $seen[$name.ToLowerInvariant()] = $true
    }
    return $list
}

function Get-PrivacyBlobFindings {
    param([string]$Name, [byte[]]$Bytes, [string[]]$Allowed, [string]$Mode = '100644')
    if ($Allowed -cnotcontains $Name) { '[unapproved-file]:0 file-not-allowlisted'; return }
    if (Test-PrivacyForbiddenPath $Name) { '[blocked-file]:0 private-artifact'; return }
    if ($Mode -notin @('100644','100755')) { "$Name`:0 link-or-special-file"; return }
    if ($Bytes.Length -gt 2097152) { "$Name`:0 oversized-file"; return }
    try { $text = Get-PrivacyText $Bytes } catch { "$Name`:0 binary-or-invalid-utf8"; return }
    Get-PrivacyTextFindings $text $Name
}

function Get-PrivacyTreeFiles {
    param([string]$Root, [string]$Relative = '')
    $directory = if ($Relative) { Join-Path $Root $Relative } else { $Root }
    foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
        $name = if ($Relative) { $Relative + '/' + $item.Name } else { $item.Name }
        if ($item.PSIsContainer -and (Test-PrivacyForbiddenPath ($name + '/'))) { continue }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            [pscustomobject]@{Name=$name; Path=$null; Mode='120000'}
        } elseif ($item.PSIsContainer) { Get-PrivacyTreeFiles $Root $name }
        else { [pscustomobject]@{Name=$name; Path=$item.FullName; Mode='100644'} }
    }
}

function Invoke-PrivacyAudit {
    param([string]$Root, [ValidateSet('Worktree','Staged','History')][string]$Mode='Worktree', [string]$Revision='HEAD')
    $Root = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]'\/')
    if ((Get-Item -LiteralPath $Root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Source root must not be a link.' }
    $manifestPath = Join-Path $Root 'source-manifest.json'
    if ($Mode -eq 'Worktree') {
        if ((Get-Item -LiteralPath $manifestPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Source manifest must not be a link.' }
        $allowed = @(Get-PrivacyManifest ([IO.File]::ReadAllBytes($manifestPath)))
        $entries = @(Get-PrivacyTreeFiles $Root)
        foreach ($entry in $entries) {
            if (-not $entry.Path) { Get-PrivacyBlobFindings $entry.Name @() $allowed $entry.Mode; continue }
            if ($allowed -cnotcontains $entry.Name) { '[unapproved-file]:0 file-not-allowlisted'; continue }
            if ((Get-Item -LiteralPath $entry.Path).Length -gt 2097152) { "$($entry.Name):0 oversized-file"; continue }
            Get-PrivacyBlobFindings $entry.Name ([IO.File]::ReadAllBytes($entry.Path)) $allowed
        }
        foreach ($name in $allowed) { if ($entries.Name -cnotcontains $name) { "$name`:0 missing-source" } }
        return
    }
    if ($Mode -eq 'Staged') {
        $allowed = @(Get-PrivacyManifest (Invoke-PrivacyGit $Root @('show',':source-manifest.json')))
        $listing = Get-PrivacyText (Invoke-PrivacyGit $Root @('ls-files','--stage','-z')) -AllowNull
        $names = @()
        foreach ($entry in ($listing -split "`0")) {
            if (-not $entry) { continue }
            if ($entry -notmatch '^(\d+) ([a-f0-9]+) (\d)\t(.+)$') { throw 'Invalid Git index entry.' }
            $fileMode=$Matches[1]; $oid=$Matches[2]; $stage=$Matches[3]; $name=$Matches[4]
            $names += $name
            if ($stage -ne '0') { '[index]:0 unresolved-conflict'; continue }
            if ($allowed -cnotcontains $name) { '[unapproved-file]:0 file-not-allowlisted'; continue }
            Get-PrivacyBlobFindings $name (Invoke-PrivacyGit $Root @('cat-file','blob',$oid)) $allowed $fileMode
        }
        foreach ($name in $allowed) { if ($names -cnotcontains $name) { "$name`:0 missing-source" } }
        return
    }
    $tip = (Get-PrivacyText (Invoke-PrivacyGit $Root @('rev-parse','--verify',($Revision + '^{commit}')))).Trim()
    $commits = (Get-PrivacyText (Invoke-PrivacyGit $Root @('rev-list','--reverse',$tip))) -split '\r?\n' | Where-Object { $_ }
    $currentAllowed = @(Get-PrivacyManifest ([IO.File]::ReadAllBytes($manifestPath)))
    $checked = @{}
    foreach ($commit in $commits) {
        $metadata = Get-PrivacyText (Invoke-PrivacyGit $Root @('cat-file','commit',$commit))
        $reviewMetadata = ($metadata -split '\r?\n' | Where-Object { $_ -notmatch '^(tree|parent) [a-f0-9]{40}$' -and $_ -cnotmatch '^committer GitHub <noreply@github\.com> \d+ [+-]\d{4}$' }) -join "`n"
        Get-PrivacyTextFindings $reviewMetadata '[commit-metadata]'
        foreach ($line in ($metadata -split '\r?\n')) {
            if ($line -match '^(author|committer) (.+) <([^>]+)> ') {
                $developer=$Matches[2] -ceq 'Andrew' -and $Matches[3] -ceq 'andrewpozdnakov7@gmail.com'
                $githubService=$Matches[1] -ceq 'committer' -and $Matches[2] -ceq 'GitHub' -and $Matches[3] -cmatch '^noreply@github\.com$'
                if (-not $developer -and -not $githubService) { '[commit-metadata]:0 unapproved-author' }
            }
        }
        $listing = Get-PrivacyText (Invoke-PrivacyGit $Root @('ls-tree','-r','-z',$commit)) -AllowNull
        $entries = @()
        $allowed = $currentAllowed
        foreach ($record in ($listing -split "`0")) {
            if (-not $record) { continue }
            if ($record -notmatch '^(\d+) (blob|commit) ([a-f0-9]+)\t(.+)$') { throw 'Invalid Git tree entry.' }
            $entry = [pscustomobject]@{Mode=$Matches[1]; Type=$Matches[2]; Oid=$Matches[3]; Name=$Matches[4]}
            $entries += $entry
            if ($entry.Name -ceq 'source-manifest.json') { $allowed = @(Get-PrivacyManifest (Invoke-PrivacyGit $Root @('cat-file','blob',$entry.Oid))) }
        }
        foreach ($entry in $entries) {
            if ($allowed -cnotcontains $entry.Name) { '[unapproved-file]:0 file-not-allowlisted'; continue }
            $key = $entry.Mode + ':' + $entry.Oid + ':' + $entry.Name
            if ($checked.ContainsKey($key)) { continue }
            $checked[$key] = $true
            if ($entry.Type -ne 'blob') { "$($entry.Name):0 submodule"; continue }
            Get-PrivacyBlobFindings $entry.Name (Invoke-PrivacyGit $Root @('cat-file','blob',$entry.Oid)) $allowed $entry.Mode
        }
    }
}
