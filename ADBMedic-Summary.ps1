# Deterministic battery evidence extraction. Unknown formats remain in raw evidence.
function New-ADBMedicAnalysisReader {
    param([string]$Path)
    if(-not ('ADBMedic.AnalysisReader' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
namespace ADBMedic {
    public sealed class AnalysisReader : IDisposable {
        private readonly StreamReader reader;
        public int SkippedLines { get; private set; }
        public AnalysisReader(string path) { reader = new StreamReader(path, new UTF8Encoding(false, false), true, 8192); }
        public string ReadLine() {
            var text = new StringBuilder(); bool any = false, oversized = false;
            int c;
            while ((c = reader.Read()) != -1) {
                any = true;
                if (c == 10) break;
                if (text.Length < 65536) text.Append((char)c); else oversized = true;
            }
            if (!any) return null;
            if (oversized) { SkippedLines++; return "ADBMEDIC_UNPARSED_OVERSIZE_LINE"; }
            return text.ToString().TrimEnd('\r');
        }
        public void Dispose() { reader.Dispose(); }
    }
}
'@
    }
    return New-Object ADBMedic.AnalysisReader($Path)
}

function ConvertTo-ADBMedicUid {
    param([string]$Text)
    if($Text -cmatch '^\d{1,9}$'){return ([long]$Text).ToString([Globalization.CultureInfo]::InvariantCulture)}
    if($Text -cnotmatch '^u(?<user>\d{1,4})(?<kind>[ais])(?<id>\d{1,5})$'){return $null}
    $user=[long]$Matches.user;$id=[long]$Matches.id;$kind=$Matches.kind
    if(($kind -eq 'a' -and $id -ge 90000) -or ($kind -eq 'i' -and $id -ge 1000) -or ($kind -eq 's' -and $id -ge 10000)){return $null}
    $offset=switch($kind){'a'{10000};'i'{99000};default{0}}
    return ($user*100000+$offset+$id).ToString([Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-ADBMedicEvidenceNumber {
    param([string]$Text)
    $value=0.0
    if([double]::TryParse($Text,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$value) -and -not [double]::IsNaN($value) -and -not [double]::IsInfinity($value) -and $value -ge 0 -and $value -le 1e12){return $value}
    return $null
}

function ConvertTo-ADBMedicDurationSeconds {
    param([string]$Text)
    $pattern='(?<value>\d+(?:\.\d+)?)(?<unit>ms|d|h|m|s)'
    $matches=[regex]::Matches($Text,$pattern)
    if(-not $matches.Count -or ([regex]::Replace($Text,$pattern,'').Trim())){return $null}
    $seconds=0.0
    foreach($match in $matches){$value=ConvertTo-ADBMedicEvidenceNumber $match.Groups['value'].Value;if($null -eq $value){return $null};$scale=switch($match.Groups['unit'].Value){'ms'{0.001};'d'{86400};'h'{3600};'m'{60};'s'{1}};$seconds+=$value*$scale}
    if($seconds -gt 315360000){return $null}
    return $seconds
}

function Get-ADBMedicBatteryAnalysis {
    param([string]$EvidenceRoot,[string[]]$UnavailableFiles=@())
    $windows=New-Object 'System.Collections.Generic.List[object]'
    $energy=New-Object 'System.Collections.Generic.List[object]'
    $counters=New-Object 'System.Collections.Generic.List[object]'
    $mappings=New-Object 'System.Collections.Generic.List[object]'
    $issues=New-Object 'System.Collections.Generic.List[object]'
    $coverage=[ordered]@{batteryLines=0;linesBeforeStatistics=0;energyRows=0;counterRows=0;unparsedCandidates=0;outputLimited=$false;packageInventory='missing';unsummarizedBatterySections=@('event history','system component energy','CPU/network details','full/draw wake locks','job completion reasons');unsummarizedFiles=@('top.txt','cpu.txt','power.txt','thermal.txt','battery-state.txt','camera.txt','sensors.txt','alarms.txt','jobs.txt','deviceidle.txt')}
    function Source([string]$file,[int]$line){return [pscustomobject]@{file=('evidence/'+$file);line=$line}}
    function Issue([string]$code,[int]$line){if($issues.Count -lt 200){$issues.Add([pscustomobject]@{code=$code;source=(Source 'battery.txt' $line)})}else{$coverage.outputLimited=$true}}
    function MapPackage([string]$uid,[string]$name,[string]$file,[int]$line){if($mappings.Count -lt 10000){$mappings.Add([pscustomobject]@{uid=$uid;package=$name;source=(Source $file $line)})}else{$coverage.outputLimited=$true}}
    $path=Join-Path $EvidenceRoot 'packages.txt'
    if(($UnavailableFiles -notcontains 'packages.txt') -and (Test-Path -LiteralPath $path -PathType Leaf)){
        $coverage.packageInventory='unrecognized-or-failed';$reader=New-ADBMedicAnalysisReader $path;$n=0
        try{while($null -ne ($line=$reader.ReadLine())){$n++;if($line -cmatch '^package:(?<package>[A-Za-z0-9_.]+)\s+uid:(?<uid>\d{1,9})(?:\s|$)'){$uid=ConvertTo-ADBMedicUid $Matches.uid;MapPackage $uid $Matches.package 'packages.txt' $n;$coverage.packageInventory='available'}}}finally{if($reader.SkippedLines){$issues.Add([pscustomobject]@{code='oversize-package-lines-not-parsed';source=(Source 'packages.txt' 1)})};$reader.Dispose()}
    }
    $path=Join-Path $EvidenceRoot 'battery.txt';$window=$null;$section=$null;$uid=$null
    $number='\d+(?:\.\d+)?(?:[eE][+-]?\d+)?';$duration='(?:\d+(?:\.\d+)?(?:ms|d|h|m|s)\s*)+'
    if(($UnavailableFiles -notcontains 'battery.txt') -and (Test-Path -LiteralPath $path -PathType Leaf)){
        $reader=New-ADBMedicAnalysisReader $path
        try{
            while($null -ne ($line=$reader.ReadLine())){
                $coverage.batteryLines++;$n=$coverage.batteryLines
                if($line -match '^\s*Statistics since (?<scope>last charge|last reset):\s*$'){
                    $scope=$Matches.scope
                    if($window){$window.endLine=$n-1};if($section){$section.endLine=$n-1}
                    if($windows.Count -ge 32){$coverage.outputLimited=$true;break}
                    $window=[pscustomobject]@{id=('window-'+($windows.Count+1));scope=$scope;source=(Source 'battery.txt' $n);endLine=$n;durations=@()}
                    $windows.Add($window);$section=$null;$uid=$null;continue
                }
                if(-not $window){$coverage.linesBeforeStatistics++;continue}
                $window.endLine=$n;if($section){$section.endLine=$n}
                if($line -match '^\S.*:\s*$' -and $line -notmatch '^Estimated power use'){
                    Issue 'unrecognized-statistics-boundary' $n
                    $window.endLine=$n-1;if($section){$section.endLine=$n-1};$window=$null;$section=$null;$uid=$null;continue
                }
                if($null -eq $uid -and $line -match '^\s*Time on battery(?<off> screen off)?:\s*(?<duration>.*?)\s*\('){
                    $kind=if($Matches.off){'screen-off-on-battery'}else{'on-battery'};$seconds=ConvertTo-ADBMedicDurationSeconds $Matches.duration
                    if($null -ne $seconds){if($window.durations.Count -lt 16){$window.durations+=,[pscustomobject]@{kind=$kind;seconds=$seconds;source=(Source 'battery.txt' $n)}}else{$coverage.outputLimited=$true}}else{Issue 'unsupported-duration' $n};continue
                }
                if($line -match '^\s*Estimated power use(?<unit>[^:]*):\s*$'){
                    if($section){$section.endLine=$n-1}
                    if($energy.Count -ge 32){$coverage.outputLimited=$true;$section=$null;continue}
                    $supported=$Matches.unit.Trim() -ceq '(mAh)'
                    $section=[pscustomobject]@{id=('energy-'+($energy.Count+1));windowId=$window.id;unit=$(if($supported){'mAh'}else{'unknown'});source=(Source 'battery.txt' $n);endLine=$n;aggregates=@();entries=@();hasUnparsedRows=$false;quality='unverified'}
                    $energy.Add($section);$uid=$null;if(-not $supported){Issue 'unsupported-energy-unit' $n};continue
                }
                if($line -match '^  (?<uid>u\d+[ais]\d+|\d{1,9}):\s*$'){$uid=ConvertTo-ADBMedicUid $Matches.uid;if($section){$section.endLine=$n-1};$section=$null;continue}
                if($section){
                    if($section.unit -ne 'mAh'){continue}
                    if($line -match ('\bComputed drain:\s*(?<value>'+$number+')(?:\s*,|\s*$)')){$value=ConvertTo-ADBMedicEvidenceNumber $Matches.value;if($null -ne $value){if($section.aggregates.Count -lt 8){$section.aggregates+=,[pscustomobject]@{valueMah=$value;source=(Source 'battery.txt' $n)}}else{$coverage.outputLimited=$true}}else{Issue 'unsupported-energy-value' $n};continue}
                    if($line -match '^\s*Uid\s+'){
                        if($line -match ('^\s*Uid\s+(?<uid>u\d+[ais]\d+|\d{1,9}):\s*(?<value>'+$number+')(?<tail>.*)$')){
                            $rawUid=$Matches.uid;$rawValue=$Matches.value;$tail=$Matches.tail;$key=ConvertTo-ADBMedicUid $rawUid;$value=ConvertTo-ADBMedicEvidenceNumber $rawValue
                            if($null -ne $key -and $null -ne $value -and $tail -match '^(?:\s|\(|$)' -and $tail -notmatch '^\s*(?:[unp]?Ah|[munp]?Wh)\b'){
                                if($coverage.energyRows -lt 10000){$section.entries+=,[pscustomobject]@{uid=$key;uidText=$rawUid;valueMah=$value;source=(Source 'battery.txt' $n)};$coverage.energyRows++}else{$coverage.outputLimited=$true}
                                continue
                            }
                        }
                        $section.hasUnparsedRows=$true;$coverage.unparsedCandidates++;Issue 'unsupported-uid-energy-row' $n
                    }
                    continue
                }
                if($null -eq $uid){continue}
                if($line -match '^\s+Apk (?<package>[A-Za-z0-9_.]+):\s*$'){MapPackage $uid $Matches.package 'battery.txt' $n;continue}
                $kind=$null;$seconds=$null;$count=$null;$tag=$null
                if($line -match ('^\s+Wake lock (?<tag>.+):\s*(?<duration>'+$duration+')\s+partial(?:\s+\((?<count>\d+) times?\))?')){$kind='partial-wakelock';$tag=$Matches.tag;$seconds=ConvertTo-ADBMedicDurationSeconds $Matches.duration;if($Matches.count){$count=ConvertTo-ADBMedicEvidenceNumber $Matches.count}}
                elseif($line -match ('^\s+Job (?<tag>.+):\s*(?<duration>'+$duration+')\s+realtime\s+\((?<count>\d+) times?\)')){$kind='job-timer-start';$tag=$Matches.tag;$seconds=ConvertTo-ADBMedicDurationSeconds $Matches.duration;$count=ConvertTo-ADBMedicEvidenceNumber $Matches.count}
                elseif($line -match '^\s+Wakeup alarm (?<tag>.+):\s*(?<count>\d+) times?\s*$'){$kind='wakeup-alarm';$tag=$Matches.tag;$count=ConvertTo-ADBMedicEvidenceNumber $Matches.count}
                elseif($line -match '^\s+(?:Wake lock|Wakeup alarm|Job)\b'){$coverage.unparsedCandidates++}
                if($kind){
                    if($tag.Length -gt 1024 -or ($null -eq $seconds -and $null -eq $count)){$coverage.unparsedCandidates++;continue}
                    if($counters.Count -ge 20000){$coverage.outputLimited=$true;continue}
                    $counters.Add([pscustomobject]@{uid=$uid;windowId=$window.id;kind=$kind;tag=$tag;durationSeconds=$seconds;count=$count;source=(Source 'battery.txt' $n)});$coverage.counterRows++
                }
            }
        }finally{if($reader.SkippedLines){Issue 'oversize-battery-lines-not-parsed' 1};$reader.Dispose()}
    }
    foreach($section in $energy){
        $seen=@{};$sum=0.0;$review=$false
        foreach($entry in $section.entries){if($seen.ContainsKey($entry.uid)){Issue 'duplicate-uid-energy' $entry.source.line;$review=$true};$seen[$entry.uid]=$true;$sum+=$entry.valueMah}
        if($section.aggregates.Count -eq 1){
            $aggregate=$section.aggregates[0].valueMah;$tolerance=[Math]::Max(0.001,$aggregate*0.005)
            if(@($section.entries|Where-Object {$_.valueMah -gt $aggregate+$tolerance}).Count){Issue 'uid-energy-exceeds-aggregate' $section.source.line;$review=$true}
            if($sum -gt $aggregate+$tolerance){Issue 'uid-energy-sum-exceeds-aggregate' $section.source.line;$review=$true}
        }elseif($section.aggregates.Count -gt 1){Issue 'ambiguous-energy-aggregate' $section.source.line;$review=$true}
        $section.quality=if($review){'needs-review'}elseif($section.hasUnparsedRows){'partial-extraction'}elseif($section.unit -eq 'mAh' -and $section.entries.Count){'parsed-not-diagnosed'}else{'unsupported'}
    }
    foreach($window in $windows){foreach($duration in $window.durations){$duration|Add-Member -NotePropertyName unit -NotePropertyValue 'seconds';$duration|Add-Member -NotePropertyName measurementKind -NotePropertyValue 'cumulative';$duration|Add-Member -NotePropertyName availability -NotePropertyValue 'available';$duration|Add-Member -NotePropertyName confidence -NotePropertyValue 'source-reported'}}
    foreach($section in $energy){
        foreach($entry in @($section.entries)+@($section.aggregates)){
            $entry|Add-Member -NotePropertyName unit -NotePropertyValue 'mAh'
            $entry|Add-Member -NotePropertyName measurementKind -NotePropertyValue 'estimated'
            $entry|Add-Member -NotePropertyName windowId -NotePropertyValue $section.windowId
            $entry|Add-Member -NotePropertyName availability -NotePropertyValue 'available'
            $entry|Add-Member -NotePropertyName confidence -NotePropertyValue $section.quality
        }
    }
    foreach($counter in $counters){$counter|Add-Member -NotePropertyName units -NotePropertyValue @{count='events';durationSeconds='seconds'};$counter|Add-Member -NotePropertyName measurementKind -NotePropertyValue 'cumulative';$counter|Add-Member -NotePropertyName availability -NotePropertyValue @{count=$(if($null -ne $counter.count){'available'}else{'unknown'});durationSeconds=$(if($null -ne $counter.durationSeconds){'available'}else{'unknown'})};$counter|Add-Member -NotePropertyName confidence -NotePropertyValue 'source-reported'}
    if($coverage.outputLimited){Issue 'parser-output-limit' $coverage.batteryLines}
    if(-not $windows.Count){Issue 'statistics-window-not-recognized' 1}
    $packages=@{};foreach($mapping in $mappings){if(-not $packages.ContainsKey($mapping.uid)){$packages[$mapping.uid]=@()};if($packages[$mapping.uid].package -cnotcontains $mapping.package){$packages[$mapping.uid]+=,$mapping}}
    $subjects=@{};foreach($section in $energy){foreach($entry in $section.entries){$subjects[$entry.uid]=$true}};foreach($counter in $counters){$subjects[$counter.uid]=$true}
    $apps=@(foreach($key in @($subjects.Keys|Sort-Object)){[pscustomobject]@{uid=$key;packages=@(if($packages.ContainsKey($key)){$packages[$key]});identityStatus=$(if($packages.ContainsKey($key)){'source-mapped'}else{'unknown-package'})}})
    return [pscustomobject]@{version=1;scope='battery-statistics';status=$(if(-not $windows.Count){'unsupported'}elseif($issues.Count -or $coverage.unparsedCandidates){'partial'}else{'parsed'});coverage=[pscustomobject]$coverage;windows=@($windows.ToArray());energySections=@($energy.ToArray());counters=@($counters.ToArray());apps=$apps;issues=@($issues.ToArray());notes=@('No rates, energy per call or culpability are inferred.','Counter durations may overlap; do not sum wake locks, jobs or background sub-timers.','Package identity comes from a current inventory or a UID-scoped Apk section; shared UID mappings remain plural.','Integrity comparisons are section-local warnings with 0.5 percent / 0.001 mAh rounding allowance, not proof that the measurement model is correct.')}
}

function New-ADBMedicSummaryMarkdown {
    param($Analysis,[string]$UI)
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $lines.Add($(if($UI -eq 'ru'){'# Первичная обработка диагностики'}else{'# Prepared diagnostic evidence'}))
    $lines.Add('')
    $lines.Add($(if($UI -eq 'ru'){'Это извлечённые факты, а не диагноз. Полные данные сохранены в evidence. Периоды, единицы и ссылки на строки обязательны при интерпретации.'}else{'These are extracted facts, not a diagnosis. Complete evidence is retained. Interpret values with their windows, units and source lines.'}))
    $lines.Add('Status: '+$Analysis.status+'; lines scanned: '+$Analysis.coverage.batteryLines+'; parsed energy rows: '+$Analysis.coverage.energyRows+'; parsed counters: '+$Analysis.coverage.counterRows+'; unparsed candidates: '+$Analysis.coverage.unparsedCandidates)
    $lines.Add('Coverage: battery statistics only. CPU snapshots, radio/network, alarm-service, job-service, power and thermal files remain available for direct AI inspection. No missing counter is assumed zero.')
    $lines.Add('Not summarized within battery.txt: '+($Analysis.coverage.unsummarizedBatterySections -join ', ')+'. Check the cited source sections when these may explain the complaint.')
    $lines.Add('Package inventory: '+$Analysis.coverage.packageInventory+'. Shared UIDs remain shared; missing package names are unknown.')
    foreach($issue in $Analysis.issues){$lines.Add('- CHECK: '+$issue.code+' — '+$issue.source.file+':'+$issue.source.line)}
    foreach($window in $Analysis.windows){$lines.Add('');$lines.Add('## '+$window.id+' / '+$window.scope+' / evidence/battery.txt:'+ $window.source.line+'-'+$window.endLine);foreach($item in $window.durations){$lines.Add('- '+$item.kind+': '+$item.seconds+' seconds; evidence/battery.txt:'+ $item.source.line)}}
    foreach($section in $Analysis.energySections){
        $lines.Add('');$lines.Add('## '+$section.id+' / '+$section.windowId+' / '+$section.quality+' / evidence/battery.txt:'+ $section.source.line+'-'+$section.endLine)
        foreach($aggregate in $section.aggregates){$lines.Add('Reported aggregate: '+$aggregate.valueMah+' mAh; evidence/battery.txt:'+ $aggregate.source.line)}
        $lines.Add('Top 15 parsed UID estimates in this section; full parsed rows are in facts.json.analysis. Unknown rows can change this ranking. Ranking is not a diagnosis.')
        $lines.Add('| UID | Packages from sources | Estimate, mAh | Source line |');$lines.Add('| --- | --- | --- | --- |')
        foreach($entry in @($section.entries|Sort-Object valueMah -Descending|Select-Object -First 15)){
            $app=$Analysis.apps|Where-Object uid -eq $entry.uid;$allNames=@($app.packages|ForEach-Object {$_.package});$names=($allNames|Select-Object -First 8) -join ', ';if($allNames.Count -gt 8){$names+=' (+more in facts.json)'};if(-not $names){$names='unknown-package'}
            $lines.Add('| '+$entry.uid+' | '+$names+' | '+$entry.valueMah+' | evidence/battery.txt:'+ $entry.source.line+' |')
        }
    }
    $lines.Add('');$lines.Add('## Selected event evidence');$lines.Add('Up to 15 longest partial wake-lock entries and 15 largest other typed counters. Durations overlap; counts represent different event types. Full parsed records remain in facts.json.analysis.counters.')
    $lines.Add('| UID | Window | Counter type | Tag | Seconds | Count | Source |');$lines.Add('| --- | --- | --- | --- | --- | --- | --- |')
    $selected=@($Analysis.counters|Where-Object kind -eq 'partial-wakelock'|Sort-Object durationSeconds -Descending|Select-Object -First 15)+@($Analysis.counters|Where-Object kind -ne 'partial-wakelock'|Sort-Object count -Descending|Select-Object -First 15)
    foreach($counter in $selected){$tag=$counter.tag.Replace('|','/').Replace("`r",' ').Replace("`n",' ');$seconds=if($null -eq $counter.durationSeconds){'not-measured'}else{[string]$counter.durationSeconds};$count=if($null -eq $counter.count){'not-measured'}else{[string]$counter.count};$lines.Add('| '+$counter.uid+' | '+$counter.windowId+' | '+$counter.kind+' | '+$tag+' | '+$seconds+' | '+$count+' | evidence/battery.txt:'+ $counter.source.line+' |')}
    $lines.Add('');$lines.Add('Read MANUAL-ANALYSIS-PROMPT.md for the diagnostic conclusion, reversible action plan and focused follow-up ADB examinations. Unsupported sections and raw event history have not been diagnosed by this parser.')
    return $lines -join "`n"
}
