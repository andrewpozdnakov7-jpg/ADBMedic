function Read-ADBMedicControlJson {
    param([string]$Path)
    $file=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if(($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.PSIsContainer -or $file.Length -gt 1048576){throw 'Invalid case metadata.'}
    return ([IO.File]::ReadAllText($file.FullName)|ConvertFrom-Json)
}

function Get-ADBMedicCaseState {
    param([string]$Session)
    $path=Join-Path $Session 'case.json'
    if(Test-Path -LiteralPath $path){
        $state=Read-ADBMedicControlJson $path
        if($state.case_id -cnotmatch '^CASE-[a-f0-9]{32}$' -or $state.schema -cne 'adbmedic.case.v1'){throw 'Invalid case identity.'}
        return $state
    }
    $state=[pscustomobject]@{schema='adbmedic.case.v1';case_id=('CASE-'+[guid]::NewGuid().ToString('N'));created=[DateTimeOffset]::Now.ToString('o');target=$null;answerLocale=$null}
    Write-ADBMedicJson $path $state
    return $state
}

function New-ADBMedicObservation {
    param([string]$Name,$Value,[string]$Unit,[string]$Kind,[string]$File,[int]$Line,$Source,[string]$Section='')
    $known=$null -ne $Value
    return [pscustomobject]@{name=$Name;value=$Value;unit=$Unit;kind=$Kind;availability=$(if($known){'available'}else{'unknown'});confidence=$(if($known){'source-reported'}else{'unknown'});source=@{file=$File;line=$(if($Line){$Line}else{$null});section=$Section};window=@{start=$Source.startedUtc;end=$Source.finishedUtc;meaning='command capture interval; historical counters may cover a different period'}}
}

function Get-ADBMedicCaseMetadata {
    param([string]$Evidence,[object[]]$Sources)
    $observations=New-Object 'System.Collections.Generic.List[object]'
    $device=[ordered]@{}
    $properties=[ordered]@{model='model';android='android';sdk='sdk';manufacturer='manufacturer';fingerprint='build-fingerprint';build='build-id';securityPatch='security-patch';hardware='hardware'}
    foreach($key in $properties.Keys){
        $name=$properties[$key]+'.txt';$source=@($Sources|Where-Object file -ceq ('evidence/'+$name))|Select-Object -First 1
        $value=$null
        if($source.status -eq 'collected'){
            $reader=[IO.File]::OpenText((Join-Path $Evidence $name))
            try{$buffer=New-Object char[] 4096;$count=$reader.ReadBlock($buffer,0,$buffer.Length);if($count -lt 4096){$value=([string]::new($buffer,0,$count)).Trim();if(-not $value){$value=$null}}}finally{$reader.Dispose()}
        }
        $device[$key]=New-ADBMedicObservation $key $value 'text' 'instant' ('evidence/'+$name) 1 $source 'selected getprop'
    }
    $specs=@(
        @('batteryPercent','battery-state.txt','^\s*level:\s*(\d+)\s*$','percent','instant','number',0,100),
        @('batteryScale','battery-state.txt','^\s*scale:\s*(\d+)\s*$','count','instant','number',1,10000),
        @('usbPowered','battery-state.txt','^\s*USB powered:\s*(true|false)\s*$','boolean','instant','boolean'),
        @('acPowered','battery-state.txt','^\s*AC powered:\s*(true|false)\s*$','boolean','instant','boolean'),
        @('wirelessPowered','battery-state.txt','^\s*Wireless powered:\s*(true|false)\s*$','boolean','instant','boolean'),
        @('wakefulness','power.txt','^\s*mWakefulness=(Awake|Asleep|Dozing|Dreaming)\s*$','state','instant','text'),
        @('uptime','uptime.txt','^\s*(\d+(?:\.\d+)?)\s+\d+(?:\.\d+)?\s*$','seconds','cumulative','number',0,1e12)
    )
    foreach($spec in $specs){
        $source=@($Sources|Where-Object file -ceq ('evidence/'+$spec[1]))|Select-Object -First 1
        $value=$null;$lineNumber=0;$foundLine=0;$matchesCount=0
        if($source.status -eq 'collected'){
            $reader=New-ADBMedicAnalysisReader (Join-Path $Evidence $spec[1])
            try{while($null -ne ($line=$reader.ReadLine())){
                $lineNumber++
                if($line -cmatch $spec[2]){
                    $matchesCount++;$foundLine=$lineNumber
                    $value=switch($spec[5]){'boolean'{$Matches[1] -ceq 'true'};'number'{ConvertTo-ADBMedicEvidenceNumber $Matches[1]};default{$Matches[1]}}
                    if($spec[5] -eq 'number' -and ($value -lt $spec[6] -or $value -gt $spec[7])){$value=$null}
                }
            }}finally{$reader.Dispose()}
        }
        if($matchesCount -ne 1){$value=$null;$foundLine=0}
        $observations.Add((New-ADBMedicObservation $spec[0] $value $spec[3] $spec[4] ('evidence/'+$spec[1]) $foundLine $source))
    }
    # A non-percent Android scale must not be silently interpreted as percent.
    $scale=$observations|Where-Object name -eq batteryScale
    if($scale.value -ne 100){$percent=$observations|Where-Object name -eq batteryPercent;$percent.value=$null;$percent.availability='unknown';$percent.confidence='unknown'}
    $conditions=[ordered]@{observations=@($observations.ToArray());screenState='unknown';samplingIntervals='see manifest command arguments and capture times';idleDischarge=@{availability='unknown';reason='No controlled unplugged start/end observation; USB capture is not an idle discharge measurement.'};notes=@('Captures are sequential, not simultaneous.','Power state at collection does not establish historical charging conditions.','wakefulness is not a verified screen on/off state.')}
    return [pscustomobject]@{device=$device;conditions=$conditions;observations=@($observations.ToArray())}
}

function Copy-ADBMedicEvidenceFile {
    param([string]$Source,[string]$Destination)
    $item=Get-Item -LiteralPath $Source -Force
    if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Evidence must be a regular file.'}
    $inputStream=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $outputStream=$null
    try{
        $outputStream=[IO.File]::Open($Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $inputStream.CopyTo($outputStream)
    }finally{if($outputStream){$outputStream.Dispose()};$inputStream.Dispose()}
    if((Get-ADBMedicHash $Source) -cne (Get-ADBMedicHash $Destination)){throw 'Evidence changed while copying.'}
}

function New-ADBMedicVerifiedZip {
    param([string]$Directory,[string[]]$Names,[string]$Destination)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if(Test-Path -LiteralPath $Destination){throw 'Archive exists.'}
    $hashes=@{};$archive=[IO.Compression.ZipFile]::Open($Destination,[IO.Compression.ZipArchiveMode]::Create)
    try{
        foreach($name in $Names){
            if($name -cnotmatch '^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*$' -or $name -match '(^|/)\.\.(/|$)' -or $hashes.ContainsKey($name)){throw 'Invalid archive member.'}
            $path=Join-Path $Directory $name;$hashes[$name]=Get-ADBMedicHash $path
            $entry=$archive.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
            $inputStream=[IO.File]::OpenRead($path);$outputStream=$entry.Open()
            try{$inputStream.CopyTo($outputStream)}finally{$outputStream.Dispose();$inputStream.Dispose()}
        }
    }finally{$archive.Dispose()}
    $archive=[IO.Compression.ZipFile]::OpenRead($Destination)
    try{
        if($archive.Entries.Count -ne $Names.Count){throw 'Archive member count differs.'}
        $seen=@{}
        foreach($entry in $archive.Entries){
            if(-not $hashes.ContainsKey($entry.FullName) -or $seen.ContainsKey($entry.FullName)){throw 'Unexpected ZIP member.'}
            $seen[$entry.FullName]=$true;$stream=$entry.Open();$hash=[Security.Cryptography.SHA256]::Create()
            try{$actual=([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose();$stream.Dispose()}
            if($actual -cne $hashes[$entry.FullName]){throw 'ZIP byte hash mismatch.'}
        }
    }finally{$archive.Dispose()}
}
