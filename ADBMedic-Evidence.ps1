# Private evidence I/O. Public source auditing is deliberately separate.
function Write-ADBMedicJson {
    param([string]$Path,$Value)
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Depth 30),[Text.UTF8Encoding]::new($false))
}

function Get-ADBMedicHash {
    param([string]$Path)
    $stream=[IO.File]::OpenRead($Path);$hash=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose();$stream.Dispose()}
}

function Assert-ADBMedicLocalDirectory {
    param([string]$Path)
    $full=[IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')
    if($full.StartsWith('\\')){throw 'A local directory is required.'}
    $item=Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if(-not $item.PSIsContainer){throw 'A directory is required.'}
    for($parent=$item;$parent;$parent=$parent.Parent){
        if($parent.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked directories are not supported.'}
    }
    return $full
}

function Get-ADBMedicBaseline {
    $items=@(
        @('cpu','dumpsys','cpuinfo'),@('top','top','-b','-d','2','-n','3'),
        @('battery','dumpsys','batterystats'),@('battery-state','dumpsys','battery'),
        @('power','dumpsys','power'),@('thermal','dumpsys','thermalservice'),
        @('camera','dumpsys','media.camera'),@('sensors','dumpsys','sensorservice'),
        @('packages','pm','list','packages','-U','--user','current'),
        @('alarms','dumpsys','alarm'),@('jobs','dumpsys','jobscheduler'),@('deviceidle','dumpsys','deviceidle'),
        @('services','dumpsys','-l'),@('uptime','cat','/proc/uptime'),
        @('device-clock','date','+%Y-%m-%dT%H:%M:%S%z'),
        @('model','getprop','ro.product.model'),@('android','getprop','ro.build.version.release'),
        @('sdk','getprop','ro.build.version.sdk'),@('manufacturer','getprop','ro.product.manufacturer'),
        @('build-fingerprint','getprop','ro.build.fingerprint'),@('build-id','getprop','ro.build.id'),
        @('security-patch','getprop','ro.build.version.security_patch'),@('hardware','getprop','ro.hardware'),
        @('display','dumpsys','display'),@('connectivity','dumpsys','connectivity'),
        @('wifi','dumpsys','wifi'),@('network','dumpsys','netstats'),@('storage','dumpsys','diskstats'),
        @('audio','dumpsys','audio'),@('processes','ps','-A','-T')
    )
    foreach($item in $items){[pscustomobject]@{id=$item[0];file=($item[0]+'.txt');arguments=(@('exec-out')+@($item[1..($item.Length-1)]))}}
}

function ConvertTo-ADBMedicNativeArgument {
    param([string]$Value)
    if($Value.Contains([char]0)){throw 'Invalid process argument.'}
    # Windows CommandLineToArgvW quoting, including trailing backslashes.
    return '"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
}

function Invoke-ADBMedicCapture {
    param([string]$Executable,[string[]]$Arguments,[string]$Directory,[string]$Name,
          [ValidateRange(1,86400)][int]$TimeoutSeconds=1200,[string]$Id='')
    if($Name -cnotmatch '^[a-z0-9-]+\.txt$'){throw 'Invalid evidence filename.'}
    $Directory=Assert-ADBMedicLocalDirectory $Directory
    $path=Join-Path $Directory $Name;$errorName=$Name.Replace('.txt','.stderr.txt');$errorPath=Join-Path $Directory $errorName
    if((Test-Path -LiteralPath $path) -or (Test-Path -LiteralPath $errorPath)){throw 'Evidence is never overwritten.'}
    $record=[ordered]@{id=$Id;file=$Name;stderrFile=$errorName;arguments=$Arguments;startedUtc=[DateTimeOffset]::UtcNow.ToString('o');finishedUtc=$null;exitCode=$null;status='capture-error';complete=$false;error='unknown';timeoutSeconds=$TimeoutSeconds;fidelity='native-bytes'}
    $output=$null;$errors=$null;$process=$null
    try{
        $output=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        $errors=[IO.File]::Open($errorPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        $command=Get-Command $Executable -ErrorAction Stop
        if($command.CommandType -ne 'Application'){
            # Synthetic tests and existing PowerShell wrappers cannot promise byte fidelity.
            $record.fidelity='text-adapter';$text=(& $Executable @Arguments | Out-String)
            $bytes=[Text.Encoding]::UTF8.GetBytes($text);$output.Write($bytes,0,$bytes.Length)
            $record.exitCode=$LASTEXITCODE;$record.complete=$true
        }else{
            $info=New-Object Diagnostics.ProcessStartInfo
            $info.FileName=$command.Source;$info.Arguments=($Arguments|ForEach-Object {ConvertTo-ADBMedicNativeArgument $_}) -join ' '
            $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
            $process=New-Object Diagnostics.Process;$process.StartInfo=$info
            [void]$process.Start()
            $outTask=$process.StandardOutput.BaseStream.CopyToAsync($output)
            $errTask=$process.StandardError.BaseStream.CopyToAsync($errors)
            $watch=[Diagnostics.Stopwatch]::StartNew()
            while(-not $process.WaitForExit(100)){
                if($outTask.IsFaulted -or $errTask.IsFaulted){$record.error='stream-write-failed';$process.Kill();break}
                if($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds){$record.status='timeout';$record.error='command-timeout';$process.Kill();break}
            }
            if(-not $process.WaitForExit(10000)){throw 'Capture process did not exit.'}
            $record.exitCode=$process.ExitCode
            if(-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($outTask,$errTask),10000)){throw 'Capture streams did not close.'}
            if($record.error -eq 'unknown'){$record.complete=$true}
        }
        if($record.complete){$record.status=if($record.exitCode -eq 0){'collected'}else{'failed'};$record.error=if($record.exitCode -eq 0){$null}else{'nonzero-exit'}}
    }catch{
        if($record.error -eq 'unknown'){$record.error='capture-or-storage-failed'}
        if($process){try{if(-not $process.HasExited){$process.Kill()}}catch{}}
    }finally{
        if($output){$output.Dispose()};if($errors){$errors.Dispose()};if($process){$process.Dispose()}
        $record.finishedUtc=[DateTimeOffset]::UtcNow.ToString('o')
    }
    return [pscustomobject]$record
}

function Get-ADBMedicEvidenceNames {
    param([object[]]$Captures)
    $names=@((Get-ADBMedicBaseline).file)+@('profile.json','symptom.txt','collection.json','locale.json','request.json','request-source.txt','followup-results.json')
    foreach($record in $Captures){
        foreach($name in @($record.file,$record.stderrFile)){
            if($name -and $name -cmatch '^[a-z0-9-]+(?:\.stderr)?\.txt$'){$names+=,$name}
            elseif($name){throw 'Invalid capture filename.'}
        }
    }
    return @($names|Select-Object -Unique)
}
