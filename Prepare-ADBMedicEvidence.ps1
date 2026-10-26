[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Session
)
$ErrorActionPreference='Stop'
try {
$sessionPath = (Resolve-Path -LiteralPath $Session).Path
$target = Join-Path $sessionPath 'analysis'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$brief = Join-Path $target 'EVIDENCE.txt'
$buffer = New-Object System.Text.StringBuilder
function Add([string]$line){[void]$buffer.AppendLine($line)}
function Line([string]$value,[int]$number) {
    $value = $value.TrimEnd()
    if ($value.Length -gt 500) { $value=$value.Substring(0,500)+' [truncated]' }
    Add ('L'+$number+': '+$value)
}
function Excerpt([string]$name,[int]$head,[string]$pattern,[int]$matchLimit) {
    $path=Join-Path $sessionPath $name
    Add ('### '+$name)
    if (-not (Test-Path -LiteralPath $path)) {Add 'File missing';Add '';return}
    $lines=[IO.File]::ReadAllLines($path,[Text.Encoding]::UTF8)
    Add ('File has '+$lines.Length+' lines. Only selected lines are included; full raw data remains on the host.')
    $chosen = New-Object 'System.Collections.Generic.HashSet[int]'
    for($i=0;$i -lt [Math]::Min($head,$lines.Length);$i++){[void]$chosen.Add($i)}
    if ($pattern) {
        $matches=0
        for($i=$head;$i -lt $lines.Length -and $matches -lt $matchLimit;$i++){
            if($lines[$i] -match $pattern) {
                for($j=[Math]::Max(0,$i-1);$j -le [Math]::Min($lines.Length-1,$i+1);$j++){
                    [void]$chosen.Add($j)
                }
                $matches++
            }
        }
    }
    foreach($i in @($chosen | Sort-Object)) {Line $lines[$i] ($i+1)}
    Add ''
}
Add '# ADBMedic / bounded diagnostic evidence'
Add 'This is a quick triage EXCERPT. Do not imply that unavailable lines were checked.'
Add 'Never assume the example Camera HAL case is occurring on this device.'
Add ''
Excerpt 'symptom.txt' 8 '' 0
Excerpt 'profile.json' 15 '' 0
Excerpt 'build.txt' 5 '' 0
# top.txt contains multiple snapshots. Keep the beginning of each, including task status and top processes.
Add '### top.txt (first 28 lines of up to 3 live samples)'
$topPath=Join-Path $sessionPath 'top.txt'
if(Test-Path -LiteralPath $topPath){
    $lines=[IO.File]::ReadAllLines($topPath,[Text.Encoding]::UTF8)
    $starts=New-Object 'System.Collections.Generic.List[int]'
    for($i=0;$i -lt $lines.Length;$i++){
        if($lines[$i] -match '^\s*Tasks:'){ $starts.Add($i) }
    }
    if($starts.Count -eq 0){$starts.Add(0)}
    $count=0
    foreach($start in $starts){
        if($count -ge 3){break}
        Add ('Live sample '+($count+1)+':')
        for($i=$start;$i -lt [Math]::Min($lines.Length,$start+28);$i++){
            Line $lines[$i] ($i+1)
        }
        $count++
    }
    Add ''
}else{Add 'top.txt missing'}
Excerpt 'cpu.txt' 42 '' 0
Excerpt 'battery.txt' 60 'Estimated power use|on battery|Discharge|Battery capacity|Screen off|Screen on|Awake|Total discharge' 20
Excerpt 'power.txt' 65 'mStayOn|mWakefulness|mHolding|Wake Locks|Display Power|mScreen' 12
Excerpt 'thermal.txt' 55 'Thermal Status|HAL Ready|temperature|Cooling Device' 12
Excerpt 'camera.txt' 15 'Active Camera Clients|Camera devices|Camera error traces|No active camera|client.pid|device [0-9]+.*closed' 25
Excerpt 'sensors.txt' 25 'Active sensors:|WakeLock Status|open event connections|Sensor Privacy|connections=[0-9]+' 15
[IO.File]::WriteAllText($brief,$buffer.ToString(),([System.Text.UTF8Encoding]::new($false)))
Write-Output 'analysis/EVIDENCE.txt'

} catch { throw 'Local report or evidence generation failed. Check the selected local session without sharing private error details.' }
