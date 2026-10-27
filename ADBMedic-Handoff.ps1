# Manual diagnostic handoff. This archive is private evidence, never a source artifact.
function Get-ADBMedicHandoffLimits {
    return [pscustomobject]@{FileBytes=67108864;TotalBytes=134217728}
}

function Stop-ADBMedicHandoff {
    param([string]$Reason,[string]$File='')
    $failure=New-Object IO.InvalidDataException('Diagnostic export rejected.')
    $failure.Data['ADBMedicReason']=$Reason
    $allowed=@('profile.json','symptom.txt','collection.json','cpu.txt','top.txt','battery.txt','battery-state.txt','power.txt','thermal.txt','camera.txt','sensors.txt','packages.txt','alarms.txt','jobs.txt','deviceidle.txt')
    if($allowed -ccontains $File){$failure.Data['ADBMedicFile']=$File}
    throw $failure
}

function Assert-ADBMedicDiagnosticText {
    param([string]$Text)
    $patterns=@(
        '-----BEGIN (?:[A-Z0-9 ]*PRIVATE KEY|CERTIFICATE)-----',
        '(?i)\b(?:gh[pousr]_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,}|sk-(?:proj-)?[a-z0-9_-]{20,}|AKIA[A-Z0-9]{16})\b',
        '\beyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\b',
        '(?i)\b(?:password|passwd|api[_-]?key|access[_-]?token|client[_-]?secret|signing[_-]?password)\s*["'']?\s*[:=]\s*["'']?[^\s"'',;}]{3,}',
        '(?i)\bAuthorization\s*:\s*(?:Bearer|Basic)\s+\S+'
    )
    foreach($pattern in $patterns){if($Text -match $pattern){Stop-ADBMedicHandoff 'secret'}}
}

function Read-ADBMedicDiagnosticText {
    param([string]$Session,[string]$Name)
    $path=Join-Path $Session $Name
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){return $null}
    $file=Get-Item -LiteralPath $path -Force
    if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){Stop-ADBMedicHandoff 'unsafe-input' $Name}
    if($file.Length -gt (Get-ADBMedicHandoffLimits).FileBytes){Stop-ADBMedicHandoff 'input-too-large' $Name}
    $bytes=[IO.File]::ReadAllBytes($path)
    if($bytes.Length -gt (Get-ADBMedicHandoffLimits).FileBytes){Stop-ADBMedicHandoff 'input-too-large' $Name}
    if($bytes -contains 0){Stop-ADBMedicHandoff 'invalid-text' $Name}
    try{$text=([Text.UTF8Encoding]::new($false,$true)).GetString($bytes).TrimStart([char]0xFEFF)}catch{Stop-ADBMedicHandoff 'invalid-text' $Name}
    try{Assert-ADBMedicDiagnosticText $text}catch{if($_.Exception.Data['ADBMedicReason'] -eq 'secret'){$_.Exception.Data['ADBMedicFile']=$Name};throw}
    return $text
}

function New-ADBMedicStartPrompt {
    param([ValidateSet('ru','en')][string]$UI,[Globalization.CultureInfo]$AnswerCulture)
    $text=if($UI -eq 'ru'){
        'Прикладываю диагностический архив ADBMedic-report.zip моего Android-телефона. Прочитай MANUAL-ANALYSIS-PROMPT.md и следуй ему, затем изучи REPORT.md, facts.json и относящиеся к жалобе файлы evidence. Выступи специалистом по диагностике Android: дай заключение с доказательствами, объясни вероятные причины и расход по реальным приложениям, укажи значения, типы и периоды измеренных событий. Дай понятный пошаговый план действий и способ проверить результат. Если данных не хватает, предложи конкретные read-only ADB-команды: зачем, как выполнить, куда сохранить вывод и что прислать. Не выдумывай отсутствующие показатели. Если архив недоступен, сообщи об этом и объясни, какие файлы приложить отдельно.'
    }else{
        'I am attaching ADBMedic-report.zip with diagnostics from my Android phone. Read and follow MANUAL-ANALYSIS-PROMPT.md, then inspect REPORT.md, facts.json and the evidence relevant to my complaint. Act as an Android diagnostic specialist: give an evidence-based conclusion, explain likely causes and energy use by real application, and report values, types and windows of measured events. Provide a clear step-by-step action plan and an outcome check. If evidence is missing, prescribe focused read-only ADB commands: why, how to run them, where to save output and what to send back. Do not invent missing measurements. If you cannot access the archive, say so and explain which files to attach separately.'
    }
    return $text+"`n`n"+$(if($UI -eq 'ru'){'Язык ответа по умолчанию: '}else{'Default answer language: '})+$AnswerCulture.NativeName+' ('+$AnswerCulture.Name+'). '+$(if($UI -eq 'ru'){'Если я явно попрошу другой язык в чате, используй его.'}else{'If I explicitly request another language in this chat, use that language instead.'})
}

function New-ADBMedicDiagnosticBundle {
    param([string]$Session,[ValidateSet('ru','en')][string]$UI='en',[string]$AnswerLocale='')
    if([string]::IsNullOrWhiteSpace($AnswerLocale)){$AnswerLocale=[Globalization.CultureInfo]::CurrentUICulture.Name}
    if([string]::IsNullOrWhiteSpace($AnswerLocale)){$AnswerLocale='en-US'}
    if($AnswerLocale -notmatch '^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$'){throw 'Invalid answer locale.'}
    $answerCulture=[Globalization.CultureInfo]::GetCultureInfo($AnswerLocale)
    $AnswerLocale=$answerCulture.Name
    $Session=Resolve-ADBMedicPrivateSession $Session
    $limits=Get-ADBMedicHandoffLimits
    $destination=Join-Path $Session 'exports'
    if(Test-Path -LiteralPath $destination){Stop-ADBMedicHandoff 'existing-export'}
    $profileText=Read-ADBMedicDiagnosticText $Session 'profile.json'
    $complaint=Read-ADBMedicDiagnosticText $Session 'symptom.txt'
    if(-not $profileText -or $null -eq $complaint){Stop-ADBMedicHandoff 'missing-context'}
    $profile=$profileText|ConvertFrom-Json
    $context=[ordered]@{model=[string]$profile.model;android=[string]$profile.android;captured=[string]$profile.captured}
    if($profile.captured -is [datetime] -or $profile.captured -is [datetimeoffset]){$context.captured=([datetimeoffset]$profile.captured).ToUniversalTime().ToString('o')}
    $captureText=Read-ADBMedicDiagnosticText $Session 'collection.json'
    $captures=@()
    if($captureText){foreach($record in (ConvertFrom-Json -InputObject $captureText)){$captures+=,$record}}
    $names=@('cpu.txt','top.txt','battery.txt','battery-state.txt','power.txt','thermal.txt','camera.txt','sensors.txt','packages.txt','alarms.txt','jobs.txt','deviceidle.txt')
    $stage=Join-Path $Session ('diagnostic-stage-'+[guid]::NewGuid().ToString('N'))
    try{
        $share=Join-Path $stage 'share'
        $evidence=Join-Path $share 'evidence'
        [IO.Directory]::CreateDirectory($evidence)|Out-Null
        $utf8=[Text.UTF8Encoding]::new($false)
        $sources=@();$total=0;$available=0
        foreach($name in $names){
            $text=Read-ADBMedicDiagnosticText $Session $name
            $status='missing';$size=0;$timing=@($captures|Where-Object {$_.file -ceq $name})
            if($timing.Count -gt 1){throw 'Duplicate capture record.'}
            $started=$null;$finished=$null;$exitCode=$null
            if($timing.Count){
                $started=([datetimeoffset]$timing[0].startedUtc).ToUniversalTime().ToString('o')
                $finished=([datetimeoffset]$timing[0].finishedUtc).ToUniversalTime().ToString('o');$exitCode=$timing[0].exitCode
                if(([datetimeoffset]$finished) -lt ([datetimeoffset]$started)){throw 'Invalid capture interval.'}
            }
            if($null -ne $text){
                $size=$utf8.GetByteCount($text);$total+=$size
                if($total -gt $limits.TotalBytes){Stop-ADBMedicHandoff 'total-too-large'}
                $status=if([string]::IsNullOrWhiteSpace($text)){'empty'}elseif($text -match '(?m)^\s*(?:Command failed:|Capture failed:)' -or ($null -ne $exitCode -and $exitCode -ne 0)){'failed'}else{'collected'}
                if($status -eq 'collected'){$available++}
                [IO.File]::WriteAllText((Join-Path $evidence $name),$text,$utf8)
            }
            $sources+=[pscustomobject][ordered]@{file=('evidence/'+$name);status=$status;bytes=$size;startedUtc=$started;finishedUtc=$finished;exitCode=$exitCode}
        }
        if(-not $available){throw 'No diagnostic evidence was collected.'}
        $facts=[ordered]@{schemaVersion=2;format='adbmedic-diagnostic-evidence';language=$AnswerLocale;interfaceLanguage=$UI;complaint=$complaint;device=$context;sources=$sources;notes=@('Capture times describe command execution, not historical counter windows.','Evidence retains real packages and UID/PID; there is no numeric P-label projection.','Unknown source formats are preserved for analysis; no computed energy totals are inferred.')}
        $intro=if($UI -eq 'ru'){'Ты — специалист по диагностике Android. Найди вероятные причины жалобы, объясни расход по приложениям и составь понятный план действий. Если данных мало, назначь конкретные дополнительные read-only ADB-команды. Следуй полному контракту ниже.'}else{'You are an Android diagnostic specialist. Investigate causes, explain application energy use and provide an actionable plan in plain language. When evidence is missing, prescribe focused read-only ADB examinations. Follow the complete contract below.'}
        $intro+="`n`nDefault answer language: "+$answerCulture.NativeName+' ('+$AnswerLocale+'). Use this Windows display locale unless the user explicitly requests another language in the AI chat; that request takes precedence. The report/interface language and English technical evidence do not override the answer language.'
        $guide=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'AI-ANALYST.md'))
        $prompt=$intro+"`n`n"+$guide
        $starter=New-ADBMedicStartPrompt -UI $UI -AnswerCulture $answerCulture
        [IO.File]::WriteAllText((Join-Path $share 'facts.json'),($facts|ConvertTo-Json -Depth 8),$utf8)
        [IO.File]::WriteAllText((Join-Path $share 'MANUAL-ANALYSIS-PROMPT.md'),$prompt,$utf8)
        [IO.File]::WriteAllText((Join-Path $share 'START-PROMPT.txt'),$starter,$utf8)
        $lines=New-Object 'System.Collections.Generic.List[string]'
        $lines.Add('# ADBMedic')
        $lines.Add('')
        if($UI -eq 'ru'){
            $lines.Add('## Что делать дальше')
            $lines.Add('Прикрепите ADBMedic-report.zip в чат нейросети, которой доверяете. Попросите выполнить MANUAL-ANALYSIS-PROMPT.md. Скрипт ничего не отправляет и не выполняет рекомендации ИИ автоматически.')
            $lines.Add('## Роль ИИ и ожидаемый результат')
            $lines.Add('Специалист по диагностике Android: заключение с доказательствами, причины расхода по реальным приложениям, различимые счётчики событий и их периоды, пошаговый план действий и проверка результата. При нехватке данных — дополнительные точечные ADB-команды с объяснением, что выполнить и какие результаты вернуть. Полная инструкция для ИИ включена в архив.')
            $lines.Add('## Содержимое и ограничения')
            $lines.Add('Архив содержит личный диагностический контекст: жалобу, модель/Android, время сбора, реальные имена процессов, пакеты и UID/PID, подробные дампы. Это не обезличенная публикация. Проверьте архив и передавайте его только выбранному ИИ. Не публикуйте его в GitHub. Проверка известных шаблонов секретов не гарантирует обнаружение всех секретов.')
        }else{
            $lines.Add('## Next step')
            $lines.Add('Attach ADBMedic-report.zip to an AI chat you trust and ask it to follow MANUAL-ANALYSIS-PROMPT.md. The script uploads nothing and does not automatically execute AI advice.')
            $lines.Add('## AI role and expected result')
            $lines.Add('Android diagnostic specialist: evidence-based conclusion, causes of energy use by real applications, clearly identified event counters and windows, detailed action plan and outcome check. Missing evidence requires focused follow-up ADB commands explaining what to run and which results to return. The full AI contract is included.')
            $lines.Add('## Contents and limitations')
            $lines.Add('This private archive retains the complaint, model/Android, capture times, real process/package names and UID/PID, and detailed dumps. Review it and share only with your chosen AI. Do not publish it on GitHub. Known-secret pattern checks do not guarantee detection of every secret.')
        }
        $lines.Add('')
        $lines.Add($(if($UI -eq 'ru'){'Язык ответа ИИ по умолчанию: '}else{'Default AI answer language: '})+$answerCulture.NativeName+' ('+$AnswerLocale+').')
        $lines.Add('')
        $lines.Add($(if($UI -eq 'ru'){'## Стартовый промпт — скопируйте в чат вместе с ZIP'}else{'## Start prompt — copy into the chat with the ZIP'}))
        $lines.Add('START-PROMPT.txt')
        $lines.Add('')
        $lines.Add($starter)
        $lines.Add('')
        $lines.Add($(if($UI -eq 'ru'){'## Контекст пользователя — диагностические данные'}else{'## User context — diagnostic data'}))
        foreach($line in (([string]$context.model+' / Android '+[string]$context.android+"`n"+$complaint) -split '\r?\n')){$lines.Add('> '+$line)}
        $lines.Add('')
        $lines.Add('| File | Collection result | Bytes |')
        $lines.Add('| --- | --- | --- |')
        foreach($source in $sources){$lines.Add('| '+$source.file+' | '+$source.status+' | '+$source.bytes+' |')}
        $lines.Add('')
        $lines.Add('Read facts.json for the complaint, device context and per-command times. Read the source files for counter definitions and historical windows. No numeric energy summary has been inferred or silently combined across sections.')
        [IO.File]::WriteAllText((Join-Path $share 'REPORT.md'),($lines -join "`n"),$utf8)
        & (Join-Path $PSScriptRoot 'Show-ADBMedicReport.ps1') -InputFile (Join-Path $share 'REPORT.md') -Language $(if($UI -eq 'ru'){'ru-RU'}else{'en-US'}) -Deterministic|Out-Null
        $files=@('REPORT.md','REPORT.html','facts.json','MANUAL-ANALYSIS-PROMPT.md','START-PROMPT.txt')+@($sources|Where-Object status -ne missing|ForEach-Object {$_.file})
        foreach($name in $files){Assert-ADBMedicDiagnosticText ([IO.File]::ReadAllText((Join-Path $share $name)))}
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archivePath=Join-Path $stage 'ADBMedic-report.zip'
        $archive=[IO.Compression.ZipFile]::Open($archivePath,[IO.Compression.ZipArchiveMode]::Create)
        try{
            foreach($name in $files){
                $entry=$archive.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
                $inputStream=[IO.File]::OpenRead((Join-Path $share $name));$outputStream=$entry.Open()
                try{$inputStream.CopyTo($outputStream)}finally{$outputStream.Dispose();$inputStream.Dispose()}
            }
        }finally{$archive.Dispose()}
        $archive=[IO.Compression.ZipFile]::OpenRead($archivePath)
        try{
            if($archive.Entries.Count -ne $files.Count){throw 'Archive content count differs.'}
            $seen=@{}
            foreach($entry in $archive.Entries){
                $name=$entry.FullName.Replace('\','/')
                if($files -cnotcontains $name -or $seen.ContainsKey($name) -or $entry.Length -gt $limits.FileBytes){throw 'Unexpected archive entry.'}
                $seen[$name]=$true
                $reader=New-Object IO.StreamReader($entry.Open(),([Text.UTF8Encoding]::new($false,$true)))
                try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
                Assert-ADBMedicDiagnosticText $text
                if($text -cne [IO.File]::ReadAllText((Join-Path $share $name))){throw 'Archive content differs.'}
            }
        }finally{$archive.Dispose()}
        [IO.File]::Move($archivePath,(Join-Path $share 'ADBMedic-report.zip'))
        [IO.Directory]::Move($share,$destination)
        return [pscustomobject]@{Ready=$true;Directory=$destination;ArchiveName='ADBMedic-report.zip';PrivateSubjects=@();SchemaVersion=2;StarterPrompt=$starter;StarterPromptFile='START-PROMPT.txt'}
    }finally{
        $target=[IO.Path]::GetFullPath($stage)
        if($target.StartsWith($Session+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($target) -match '^diagnostic-stage-[a-f0-9]{32}$' -and [IO.Directory]::Exists($target)){
            if((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Unsafe cleanup target.'}
            [IO.Directory]::Delete($target,$true)
        }
    }
}
