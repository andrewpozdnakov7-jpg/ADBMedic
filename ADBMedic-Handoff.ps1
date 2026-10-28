# Diagnostic ZIP v3: byte-preserving private evidence, never a public source artifact.
. (Join-Path $PSScriptRoot 'ADBMedic-Evidence.ps1')
. (Join-Path $PSScriptRoot 'ADBMedic-Case.ps1')

function New-ADBMedicStartPrompt {
    param([ValidateSet('ru','en')][string]$UI,[Globalization.CultureInfo]$AnswerCulture)
    $text=if($UI -eq 'ru'){
        'Прикладываю диагностический ZIP ADBMedic. Прочитай INVESTIGATE.md, manifest.json и symptom.txt. Исследуй причину моей проблемы по доказательствам: проверь условия сбора, сравни возможные объяснения, укажи источники и степень уверенности. Объясни, что установлено и что пока неизвестно. Дай понятные действия и способ проверить результат. Если данных недостаточно, выбери 1–3 проверки из agent/check-catalog.json и подготовь followup-request.json для этого случая; объясни, как выполнить его локально. Не выдумывай показатели и не выполняй команды автоматически. Если ZIP недоступен, скажи об этом.'
    }else{
        'I am attaching an ADBMedic diagnostic ZIP. Read INVESTIGATE.md, manifest.json and symptom.txt. Investigate my complaint using evidence: validate collection conditions, compare plausible explanations, cite sources and confidence. Explain what is established and unknown, give practical steps and an outcome check. If evidence is insufficient, select 1–3 checks from agent/check-catalog.json and prepare followup-request.json for this case; explain how to run it locally. Do not invent measurements or execute commands automatically. Say if the attachment cannot be accessed.'
    }
    return $text+"`n`nDefault answer language: "+$AnswerCulture.NativeName+' ('+$AnswerCulture.Name+'). An explicit language request in this chat takes precedence.'
}

function New-ADBMedicDiagnosticBundle {
    param([string]$Session,[ValidateSet('ru','en')][string]$UI='en',[string]$AnswerLocale='')
    if(-not $AnswerLocale){$AnswerLocale=[Globalization.CultureInfo]::CurrentUICulture.Name}
    if(-not $AnswerLocale){$AnswerLocale='en-US'}
    if($AnswerLocale -notmatch '^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$'){throw 'Invalid answer locale.'}
    $culture=[Globalization.CultureInfo]::GetCultureInfo($AnswerLocale)
    $Session=Assert-ADBMedicLocalDirectory $Session
    $destination=Join-Path $Session 'exports'
    if(Test-Path -LiteralPath $destination){throw 'Existing export was preserved.'}
    $captures=@();$metadataIssues=@()
    if(Test-Path -LiteralPath (Join-Path $Session 'collection.json')){
        try{$captures=@(Read-ADBMedicControlJson (Join-Path $Session 'collection.json'))}catch{$metadataIssues+='collection-metadata-unreadable'}
    }
    $names=Get-ADBMedicEvidenceNames $captures
    if(-not $captures.Count -and -not (Test-Path -LiteralPath (Join-Path $Session 'symptom.txt')) -and -not @((Get-ADBMedicBaseline).file|Where-Object {Test-Path -LiteralPath (Join-Path $Session $_) -PathType Leaf}).Count){throw 'No diagnostic case inputs exist.'}
    $state=Get-ADBMedicCaseState $Session
    $stage=Join-Path $Session ('diagnostic-stage-'+[guid]::NewGuid().ToString('N'))
    try{
        $share=Join-Path $stage 'share';$evidence=Join-Path $share 'evidence'
        [IO.Directory]::CreateDirectory($evidence)|Out-Null
        $sources=@();$files=@();$manifestFiles=@()
        foreach($name in $names){
            $sourcePath=Join-Path $Session $name
            $timing=@($captures|Where-Object {$_.file -ceq $name -or $_.stderrFile -ceq $name})
            if($timing.Count -gt 1){throw 'Duplicate capture record.'}
            $record=$timing|Select-Object -First 1
            $status=if($record.status){$record.status}else{'missing'};$size=0;$hash=$null;$complete=$null
            if(Test-Path -LiteralPath $sourcePath){
                $target=Join-Path $evidence $name
                Copy-ADBMedicEvidenceFile $sourcePath $target
                $size=(Get-Item -LiteralPath $target).Length;$hash=Get-ADBMedicHash $target
                $status=if($record.status){$record.status}elseif($null -ne $record.exitCode -and $record.exitCode -ne 0){'failed'}elseif($record){'collected'}else{'unverified'}
                $complete=$record.complete
                $files+=,('evidence/'+$name)
                $manifestFiles+=,[pscustomobject]@{file=('evidence/'+$name);originalFilename=$name;bytes=$size;sha256=$hash}
            }
            $arguments=@($record.arguments)
            # The target is bound locally; source metadata must not invent a serial.
            if($arguments.Count -ge 2 -and $arguments[0] -eq '-s'){$arguments=@($arguments|Select-Object -Skip 2)}
            $sources+=,[pscustomobject]@{file=('evidence/'+$name);status=$status;bytes=$size;sha256=$hash;id=$record.id;arguments=$arguments;legacyCommand=$record.command;startedUtc=$record.startedUtc;finishedUtc=$record.finishedUtc;exitCode=$record.exitCode;complete=$complete;error=$record.error;timeoutSeconds=$record.timeoutSeconds;fidelity=$record.fidelity;omissionReason=$(if($null -eq $hash){if($record.error){$record.error}else{'not captured or file unavailable'}}else{$null})}
        }
        . (Join-Path $PSScriptRoot 'ADBMedic-Summary.ps1')
        $unavailable=@($sources|Where-Object {$_.status -notin @('collected','unverified')}|ForEach-Object {Split-Path -Leaf $_.file})
        try{$analysis=Get-ADBMedicBatteryAnalysis $evidence -UnavailableFiles $unavailable;$summary=New-ADBMedicSummaryMarkdown $analysis $UI}
        catch{$analysis=@{version=1;status='unsupported';reason='derived analysis unavailable; raw evidence retained'};$summary='Derived analysis unavailable. Inspect manifest.json and original evidence.'}
        $meta=Get-ADBMedicCaseMetadata $evidence $sources
        $complaint='Unknown / general check'
        $symptomPath=Join-Path $Session 'symptom.txt'
        if(Test-Path -LiteralPath $symptomPath){Copy-ADBMedicEvidenceFile $symptomPath (Join-Path $share 'symptom.txt')}
        else{[IO.File]::WriteAllText((Join-Path $share 'symptom.txt'),$complaint,[Text.UTF8Encoding]::new($false))}
        # Only the display preview is bounded; symptom.txt and evidence remain complete.
        $reader=[IO.File]::OpenText((Join-Path $share 'symptom.txt'))
        try{$buffer=New-Object char[] 4096;$count=$reader.ReadBlock($buffer,0,4096);$complaint=[string]::new($buffer,0,$count)}finally{$reader.Dispose()}
        $facts=[ordered]@{schemaVersion=3;format='adbmedic-diagnostic-evidence';case_id=$state.case_id;language=$culture.Name;interfaceLanguage=$UI;complaint=$complaint;complaintPreviewOnly=$true;observations=$meta.observations;analysis=$analysis;notes=@('Original evidence is byte-preserved; derived facts are not a diagnosis.','No idle discharge, battery health or energy per event is inferred.','Every analysis record inherits its window and counter kind; modeled mAh are estimated, not measured current.')}
        Write-ADBMedicJson (Join-Path $share 'facts.json') $facts
        Write-ADBMedicJson (Join-Path $share 'device.json') $meta.device
        Write-ADBMedicJson (Join-Path $share 'conditions.json') $meta.conditions
        $starter=New-ADBMedicStartPrompt $UI $culture
        [IO.File]::WriteAllText((Join-Path $share 'START-PROMPT.txt'),$starter,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $share 'SUMMARY.md'),$summary,[Text.UTF8Encoding]::new($false))
        foreach($name in @('INVESTIGATE.md','agent/investigation-rules.md','agent/check-catalog.json','agent/followup-request.example.json')){
            $target=Join-Path $share $name
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
            Copy-ADBMedicEvidenceFile (Join-Path $PSScriptRoot $name) $target
        }
        $report=if($UI -eq 'ru'){
            "# ADBMedic`n`nОтчёт о сборе, не диагноз. Случай: "+$state.case_id+"`n`nПрикрепите подготовленный ZIP в чат доверенного ИИ и скопируйте START-PROMPT.txt. Инструкция INVESTIGATE.md уже внутри. Автоматической отправки нет.`n`nАрхив не обезличен: реальные пакеты, UID/PID/TID, сборка и полные технические ответы сохранены. Возможны чувствительные сведения. Передавайте только тому ИИ, которому доверяете; не публикуйте в GitHub.`n"
        }else{
            "# ADBMedic`n`nCollection report, not a diagnosis. Case: "+$state.case_id+"`n`nAttach the prepared ZIP to your trusted AI chat and copy START-PROMPT.txt. INVESTIGATE.md is included. Nothing is uploaded automatically.`n`nThis archive is not anonymized. Real packages, UID/PID/TID, build details and full technical responses are retained. Sensitive information may be present. Share only with your chosen AI, never on GitHub.`n"
        }
        $report+="`n| File | Result | Bytes |`n| --- | --- | --- |`n"
        foreach($source in $sources){$report+='| '+$source.file+' | '+$source.status+' | '+$source.bytes+" |`n"}
        $report+="`n## START-PROMPT.txt`n`n"+$starter+"`n`n"+$summary
        [IO.File]::WriteAllText((Join-Path $share 'REPORT.md'),$report,[Text.UTF8Encoding]::new($false))
        & (Join-Path $PSScriptRoot 'Show-ADBMedicReport.ps1') -InputFile (Join-Path $share 'REPORT.md') -Language $culture.Name -Deterministic|Out-Null
        $files+=@('symptom.txt','facts.json','device.json','conditions.json','START-PROMPT.txt','SUMMARY.md','REPORT.md','REPORT.html','INVESTIGATE.md','agent/investigation-rules.md','agent/check-catalog.json','agent/followup-request.example.json')
        foreach($name in $files|Where-Object {-not $_.StartsWith('evidence/')}){$manifestFiles+=,[pscustomobject]@{file=$name;originalFilename=$name;bytes=(Get-Item -LiteralPath (Join-Path $share $name)).Length;sha256=(Get-ADBMedicHash (Join-Path $share $name))}}
        $times=@($captures|ForEach-Object {$_.startedUtc;$_.finishedUtc}|Where-Object {$_}|Sort-Object)
        $manifest=[ordered]@{schema='adbmedic.manifest.v1';case_id=$state.case_id;round_id=$state.round_id;parent_case_id=$state.parent_case_id;created=[DateTimeOffset]::Now.ToString('o');captureStart=$(if($times.Count){$times[0]}else{$null});captureEnd=$(if($times.Count){$times[-1]}else{$null});collectorVersion='0.2.0-dev';answerLanguage=$culture.Name;capabilities=@{services='evidence/services.txt, if available';sdk='device.json.sdk';commandSupport='actual outcomes in commands; no success assumed from Android version'};commands=$sources;files=$manifestFiles;metadataIssues=$metadataIssues;limitations=@('No anonymization or universal secret detection. No automatic upload.','Command timeout retains partial bytes; abrupt termination or storage failure may prevent final packaging.','manifest.json excludes its own hash to avoid self-reference.','No unrestricted logcat, bugreport, app files, SMS, notifications or message content are requested by baseline.')}
        Write-ADBMedicJson (Join-Path $share 'manifest.json') $manifest
        $files+=,'manifest.json'
        $archiveName=if($state.round_id){'ADBMedic-followup-'+$state.round_id+'.zip'}else{'ADBMedic-report.zip'}
        $archivePath=Join-Path $stage $archiveName
        New-ADBMedicVerifiedZip $share $files $archivePath
        [IO.File]::Move($archivePath,(Join-Path $share $archiveName))
        [IO.Directory]::Move($share,$destination)
        return [pscustomobject]@{Ready=$true;Directory=$destination;ArchiveName=$archiveName;SchemaVersion=3;CaseId=$state.case_id;StarterPrompt=$starter;StarterPromptFile='START-PROMPT.txt'}
    }finally{
        if([IO.Directory]::Exists($stage)){
            $stage=Assert-ADBMedicLocalDirectory $stage
            if([IO.Path]::GetDirectoryName($stage) -cne $Session -or [IO.Path]::GetFileName($stage) -notmatch '^diagnostic-stage-[a-f0-9]{32}$'){throw 'Unsafe cleanup target.'}
            [IO.Directory]::Delete($stage,$true)
        }
    }
}
