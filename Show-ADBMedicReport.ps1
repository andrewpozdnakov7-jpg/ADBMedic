[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [switch]$Open,
    [string]$Language='auto',
    [switch]$Deterministic
)
$ErrorActionPreference = 'Stop'
try {
. (Join-Path $PSScriptRoot 'ADBMedic-Locale.ps1')
$folder=Split-Path -Parent (Resolve-Path -LiteralPath $InputFile).Path
$locale=Resolve-ADBMedicLanguage -Language $Language -Session $folder
$t=Get-ADBMedicText -UI $locale.UI

function EscapeText([string]$value) {
    $result = [System.Net.WebUtility]::HtmlEncode($value)
    $result = [regex]::Replace($result, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $tick = [regex]::Escape([string][char]96)
    $result = [regex]::Replace($result, ($tick + '([^' + $tick + ']+)' + $tick), '<code>$1</code>')
    return $result
}

$markdown = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $InputFile).Path, [Text.Encoding]::UTF8)
$body = New-Object System.Text.StringBuilder
$inCode = $false
$inList = $false
$listTag = ''
$inTable = $false
$tableRows = 0
$paragraph = New-Object 'System.Collections.Generic.List[string]'

function AddLine([string]$value) {
    [void]$body.AppendLine($value)
}
function FlushParagraph {
    if ($paragraph.Count -gt 0) {
        AddLine ('<p>' + ($paragraph -join ' ') + '</p>')
        $paragraph.Clear()
    }
}
function CloseListsAndTables {
    FlushParagraph
    if ($script:inList) {
        AddLine ('</' + $script:listTag + '>')
        $script:inList = $false
    }
    if ($script:inTable) {
        AddLine '</tbody></table>'
        $script:inTable = $false
    }
}

$backtick = [string][char]96
$fence = $backtick * 3

foreach ($line in $markdown) {
    $trimmed = $line.Trim()
    if ($trimmed.StartsWith($fence)) {
        CloseListsAndTables
        if ($inCode) {
            AddLine '</code></pre>'
            $inCode = $false
        } else {
            AddLine '<pre><code>'
            $inCode = $true
        }
        continue
    }
    if ($inCode) {
        AddLine ([System.Net.WebUtility]::HtmlEncode($line))
        continue
    }
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        CloseListsAndTables
        continue
    }
    if ($trimmed -match '^#{1,4}\s+') {
        CloseListsAndTables
        $m = [regex]::Match($trimmed, '^(#{1,4})\s+(.+)$')
        $level = $m.Groups[1].Value.Length
        AddLine ('<h' + $level + '>' + (EscapeText $m.Groups[2].Value) + '</h' + $level + '>')
        continue
    }
    if ($trimmed -match '^\|.*\|\s*$') {
        FlushParagraph
        if ($inList) {
            AddLine ('</' + $listTag + '>')
            $inList = $false
        }
        if ($trimmed -match '^\|?\s*:?-{3,}[: -]*\|') { continue }
        $cells = @($trimmed.Trim([char]'|').Split([char]'|') | ForEach-Object {$_.Trim()})
        if (-not $inTable) {
            AddLine '<table><thead><tr>'
            foreach ($cell in $cells) { AddLine ('<th>' + (EscapeText $cell) + '</th>') }
            AddLine '</tr></thead><tbody>'
            $inTable = $true
            $tableRows = 0
        } else {
            AddLine '<tr>'
            foreach ($cell in $cells) { AddLine ('<td>' + (EscapeText $cell) + '</td>') }
            AddLine '</tr>'
            $tableRows++
        }
        continue
    }
    if ($inTable) {
        AddLine '</tbody></table>'
        $inTable = $false
    }
    $item = [regex]::Match($trimmed, '^[-*]\s+(.+)$')
    $numbered = [regex]::Match($trimmed, '^\d+[.)]\s+(.+)$')
    if ($item.Success -or $numbered.Success) {
        FlushParagraph
        $wantedTag = if ($numbered.Success) {'ol'} else {'ul'}
        if ($inList -and $listTag -ne $wantedTag) {
            AddLine ('</' + $listTag + '>')
            $inList = $false
        }
        if (-not $inList) {
            AddLine ('<' + $wantedTag + '>')
            $inList = $true
            $listTag = $wantedTag
        }
        $value = if ($numbered.Success) {$numbered.Groups[1].Value} else {$item.Groups[1].Value}
        AddLine ('<li>' + (EscapeText $value) + '</li>')
        continue
    }
    if ($inList) {
        AddLine ('</' + $listTag + '>')
        $inList = $false
    }
    if ($trimmed -match '^>\s*(.*)$') {
        FlushParagraph
        AddLine ('<blockquote>' + (EscapeText $Matches[1]) + '</blockquote>')
        continue
    }
    if ($trimmed -match '^---+$') {
        FlushParagraph
        AddLine '<hr>'
        continue
    }
    $paragraph.Add((EscapeText $trimmed))
}
CloseListsAndTables
if ($inCode) { AddLine '</code></pre>' }

$style = @'
:root{color-scheme:dark;font-family:Segoe UI,Arial,sans-serif}
*{box-sizing:border-box}
body{margin:0;background:#0c111a;color:#e5ebf5;line-height:1.65}
.shell{max-width:980px;margin:0 auto;padding:24px 20px 72px}
.header{display:flex;justify-content:space-between;gap:15px;align-items:center;padding:18px 0;border-bottom:1px solid #263141}
.identity{display:flex;gap:12px;align-items:center}
.logo{display:grid;place-items:center;width:44px;height:44px;background:#172b43;border:1px solid #28537a;border-radius:13px;color:#8fc9ff;font-size:24px}
.name{font-size:20px;font-weight:750;letter-spacing:.2px}
.subtitle,.status{font-size:12px;color:#a3b2c7}
.status{border:1px solid #34475e;border-radius:999px;padding:6px 10px;text-align:center}
.hero{margin:30px 0 22px}
.kicker{font-size:12px;text-transform:uppercase;letter-spacing:1.5px;color:#84c9ff;font-weight:700}
.hero h1{font-size:clamp(28px,4vw,42px);line-height:1.2;margin:9px 0}
.hero p{color:#bac8dc;margin:0}
.report{background:#121b28;border:1px solid #2a394b;border-radius:17px;padding:24px clamp(18px,4vw,42px);box-shadow:0 16px 40px #0003}
.report h1{font-size:27px;line-height:1.3}
.report h2{font-size:21px;line-height:1.35;margin:32px 0 13px;padding-top:8px;color:#f3f7ff;border-top:1px solid #283648}
.report h3{font-size:17px;color:#a8d5ff;margin:24px 0 10px}
.report p{margin:11px 0}
.report strong{color:#f6faff}
.report ul,.report ol{padding-left:24px}
.report li{padding:4px 0}
.report li::marker{color:#80bfff}
.report blockquote{border-left:3px solid #5198d8;background:#172439;margin:14px 0;padding:8px 16px;color:#ccdeef}
.report code{font-family:Consolas,'Cascadia Code',monospace;background:#203047;color:#b9e1ff;padding:2px 6px;border-radius:5px;font-size:.93em;overflow-wrap:anywhere}
.report pre{border:1px solid #334458;background:#0b1420;border-radius:10px;padding:15px;overflow:auto}
.report pre code{background:none;padding:0;color:#d4edff}
.report table{border-collapse:collapse;display:block;max-width:100%;overflow:auto;margin:18px 0}
.report td,.report th{border:1px solid #30415a;padding:10px 12px;text-align:left;vertical-align:top}
.report th{background:#1b2c42;color:#d8ecff}
.report hr{border:0;border-top:1px solid #334458;margin:20px 0}
.footer{padding-top:18px;font-size:12px;color:#8b9cb3}
@media(max-width:600px){.shell{padding:12px 11px 35px}.report{padding:16px}.status{display:none}}
'@
$now=if($Deterministic){''}else{(Get-Date).ToString('yyyy-MM-dd HH:mm')}
$html='<!doctype html><html lang="'+[System.Net.WebUtility]::HtmlEncode($locale.Locale)+'"><head>'
$html+='<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
$html+='<meta http-equiv="Content-Security-Policy" content="default-src '+[string][char]39+'none'+[string][char]39+'; style-src '+[string][char]39+'unsafe-inline'+[string][char]39+'; img-src '+[string][char]39+';">'
$html+='<title>ADBMedic - '+(EscapeText $t.title)+'</title><style>'+$style+'</style></head><body>'
$html+='<div class="shell"><header class="header"><div class="identity"><div class="logo">&#8981;</div><div><div class="name">ADBMedic</div><div class="subtitle">'+(EscapeText $t.preliminary)+'</div></div></div><div class="status">'+(EscapeText $t.browser)+'</div></header>'
$html+='<section class="hero"><div class="kicker">'+(EscapeText $t.title)+'</div><h1>'+(EscapeText $t.heroTitle)+'</h1><p>'+(EscapeText $t.heroDesc)+'</p></section>'
$html+='<article class="report">'+$body.ToString()+'</article>'
$footer=if($Deterministic){EscapeText $t.privacy}else{(EscapeText $t.created)+' '+(EscapeText $now)+'. '+(EscapeText $t.privacy)}
$html+='<footer class="footer">'+$footer+'</footer></div></body></html>'
$destination=Join-Path $folder 'REPORT.html'
[IO.File]::WriteAllText($destination,$html,([System.Text.UTF8Encoding]::new($false)))
Write-Output 'REPORT.html'
if($Open){Start-Process -FilePath $destination}

} catch { throw 'Local report or evidence generation failed. Check the selected local session without sharing private error details.' }
