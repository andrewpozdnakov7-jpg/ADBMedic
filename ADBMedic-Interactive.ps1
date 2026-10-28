# Local case UI. All diagnostics and request validation remain in ADBMedic-Followup.ps1.
. (Join-Path $PSScriptRoot 'ADBMedic-Handoff.ps1')
. (Join-Path $PSScriptRoot 'ADBMedic-Followup.ps1')
. (Join-Path $PSScriptRoot 'ADBMedic-Device.ps1')

function Get-ADBMedicInteractiveText {
    param([string]$UI='en')
    if($UI -eq 'ru'){return @{
        copy='Скопируйте промпт в чат вместе с ZIP (START-PROMPT.txt):';ready='ADBMedic — расследование';resume='1. Продолжить последнее расследование (Enter)';other='2. Выбрать другое расследование';new='3. Начать новую диагностику';exit='0. Завершить — случай сохранён'
        startup='Продолжить, выбрать другой случай или начать новый?';chooseCase='Номер случая; Enter — отмена';ambiguous='Несколько случаев имеют одинаковое время. Выберите нужный номер.';legacy='Найден сохранённый случай без совместимых метаданных или привязки телефона. Для него нужна новая диагностика; файлы сохранены.'
        report='1. Открыть локальный отчёт';folder='2. Открыть папку с ZIP';request='3. У меня есть новый запрос от ИИ';retry='4. Повторить упаковку сохранённых данных';menu='Номер пункта; Enter — завершить';invalid='Выберите один из показанных пунктов.'
        file='1. Выбрать скачанный JSON';paste='2. Вставить JSON';downloads='3. Найти запросы в Загрузках';import='Как добавить запрос? Enter — отмена';path='Путь к JSON; Enter — отмена';picker='Выберите запрос ИИ (*.json)';pickerUnavailable='Выбор файла недоступен. Введите путь к скачанному JSON.'
        pasteHelp='Вставьте JSON, можно вместе с блоком ```json. На отдельной строке введите END. CANCEL — отмена. Лимит 64 КиБ.';line='';downloadChoice='Номер файла; Enter — отмена';noDownloads='В Загрузках не найден followup-request.json. Выберите файл или вставьте JSON.'
        confirm='Выполнить перечисленные проверки? [y/N]';notice='Это локальные read-only измерения. Автоматической отправки нет.';sensitive='Проверка может содержать сведения о местоположении, сети или чувствительные строки журналов.';reconnect='Подключите и разблокируйте исходный телефон; подтвердите USB-отладку, если потребуется.'
        attach='Прикрепите этот НОВЫЙ ZIP в тот же чат ИИ.';cancelled='Отменено. Случай сохранён.';partial='Предыдущая попытка могла быть прервана. Данные сохранены; тот же запрос автоматически не повторяется.';missingZip='ZIP пока недоступен. Можно открыть папку и повторить упаковку сохранённых данных.';openFailed='Не удалось открыть окно. Случай сохранён.'
    }}
    return @{
        copy='Copy this prompt into the chat with the ZIP (START-PROMPT.txt):';ready='ADBMedic — investigation';resume='1. Resume latest investigation (Enter)';other='2. Choose another investigation';new='3. Start a new baseline';exit='0. Exit — case is saved'
        startup='Resume, choose another case, or start new?';chooseCase='Case number; Enter to cancel';ambiguous='Cases have the same timestamp. Choose the intended case explicitly.';legacy='A saved case lacks compatible metadata or device binding. Collect a new baseline for it; original files are retained.'
        report='1. Open local report';folder='2. Open ZIP folder';request='3. I have a new request from my AI investigator';retry='4. Retry packaging saved evidence';menu='Menu choice; Enter to finish';invalid='Choose one of the displayed options.'
        file='1. Choose downloaded JSON';paste='2. Paste JSON';downloads='3. Find requests in Downloads';import='How would you like to import? Enter to cancel';path='JSON file path; Enter to cancel';picker='Choose an AI request (*.json)';pickerUnavailable='File picker unavailable. Enter the downloaded JSON path.'
        pasteHelp='Paste JSON, optionally including its ```json fence. Finish with END on a separate line. CANCEL cancels. Limit: 64 KiB.';line='';downloadChoice='File number; Enter to cancel';noDownloads='No followup-request.json found in Downloads. Choose a file or paste JSON.'
        confirm='Run these checks? [y/N]';notice='These are local read-only measurements. Nothing is uploaded automatically.';sensitive='This check may contain location/network information or sensitive diagnostic log strings.';reconnect='Connect and unlock the original phone; authorize USB debugging if asked.'
        attach='Attach this NEW ZIP to the SAME AI conversation.';cancelled='Cancelled. The case is saved.';partial='A previous attempt may have been interrupted. Evidence is retained; the same request is not automatically replayed.';missingZip='ZIP is not ready. Open the folder or retry packaging saved evidence.';openFailed='Could not open the window. The case is saved.'
    }
}

function Write-ADBMedicInteractiveError {
    param($ErrorRecord,[string]$UI='en')
    $code=[string]$ErrorRecord.Exception.Data['ADBMedicRequestCode']
    $field=[string]$ErrorRecord.Exception.Data['ADBMedicRequestField']
    if($field -cnotin @('request','case','schema','case_id','fields','checks','checks.fields','checks.parameters','checks.id','checks.target_pid','checks.samples','checks.interval_seconds','reason','schema / fields')){$field='request / case'}
    $ru=$UI -eq 'ru'
    $message=switch($code){
        'size' {if($ru){'JSON должен содержать от 1 байта до 64 КиБ.'}else{'JSON must contain 1 byte to 64 KiB.'}}
        'encoding' {if($ru){'Нужен текст JSON в UTF-8.'}else{'UTF-8 JSON text is required.'}}
        'fence' {if($ru){'Скопируйте один полный блок JSON, без пояснений снаружи. Проверьте строки ```json и ```.'}else{'Copy one complete JSON block without surrounding prose. Check the ```json and ``` delimiters.'}}
        'json' {if($ru){'JSON не разобран. Скопируйте весь объект с фигурными скобками; команды PowerShell не подходят.'}else{'Malformed JSON. Copy the complete object including braces; PowerShell commands are not accepted.'}}
        'schema' {if($ru){'schema: требуется adbmedic.followup.v1.'}else{'schema: expected adbmedic.followup.v1.'}}
        'case' {if($ru){'case_id не соответствует открытому случаю. Попросите ИИ использовать ID из его manifest.json.'}else{'case_id does not match the open case. Ask the AI to use its manifest.json case ID.'}}
        'validation' {if($ru){'Проверьте поле '+$field+'. Разрешены schema, case_id, reason, checks; внутри checks — id и параметры из каталога.'}else{'Check '+$field+'. Allowed fields: schema, case_id, reason, checks; each check accepts id and catalog parameters only.'}}
        'unsupported' {if($ru){'checks.id: проверка недоступна в этой версии. Попросите ИИ выбрать доступную проверку из каталога.'}else{'checks.id: unavailable in this version. Ask the AI to select an available catalog check.'}}
        'unknown-check' {if($ru){'checks.id: неизвестная проверка. Попросите ИИ использовать agent/check-catalog.json из архива.'}else{'checks.id: unknown check. Ask the AI to use agent/check-catalog.json from the archive.'}}
        'replay' {if($ru){'Этот запрос уже выполнялся или был прерван. Используйте предыдущий результат либо запросите у ИИ новый запрос с объяснением повторного измерения.'}else{'This request was already attempted or interrupted. Use the previous result, or ask the AI for a new request explaining the repeated measurement.'}}
        'busy' {if($ru){'Этот случай уже используется другим окном. Завершите там сбор и повторите выбор.'}else{'Another window is using this case. Finish that collection before trying again.'}}
        'device' {if($ru){'Выбран другой телефон или отсутствует привязка. Подключите исходный телефон; старому случаю без привязки нужна новая диагностика.'}else{'Wrong phone or missing binding. Connect the original phone; an unbound old case needs a new baseline.'}}
        'build' {if($ru){'Сборка телефона отличается или не прочитана. Проверьте подключение; после обновления ОС соберите новую диагностику.'}else{'Device build differs or could not be read. Check the connection; collect a new baseline after an OS update.'}}
        'adb' {if($ru){'ADB не найден. Начните новую диагностику для установки инструмента либо восстановите его локальную установку.'}else{'ADB is missing. Start a new baseline to install the tool, or restore the local ADB installation.'}}
        'history' {if($ru){'Не удалось проверить историю попыток этого случая. Данные сохранены; автоматическое повторение заблокировано.'}else{'Could not verify this case history. Evidence is retained; automatic replay is blocked.'}}
        default {if($ru){'Не удалось прочитать запрос, метаданные или завершить сбор/упаковку. Проверьте файл, подключение и свободное место. Данные случая сохранены.'}else{'Could not read the request/metadata or finish collection/packaging. Check the file, connection and free space. Case data is retained.'}}
    }
    Write-Warning $message
}

function Read-ADBMedicRequestFile {
    param([string]$Path,[string]$CaseId)
    $Path=$Path.Trim().Trim('"')
    [void](Assert-ADBMedicLocalDirectory ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))))
    $file=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)){Stop-ADBMedicRequest 'file' 'request'}
    $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
        if($stream.Length -lt 1 -or $stream.Length -gt 65536){Stop-ADBMedicRequest 'size' 'request'}
        $buffer=New-Object byte[] ([int]$stream.Length);$offset=0
        while($offset -lt $buffer.Length){$count=$stream.Read($buffer,$offset,$buffer.Length-$offset);if(-not $count){throw 'Incomplete request read.'};$offset+=$count}
    }finally{$stream.Dispose()}
    return ConvertFrom-ADBMedicRequestBytes $buffer $CaseId
}

function Read-ADBMedicPastedRequest {
    param([string]$CaseId,[string]$UI='en')
    $t=Get-ADBMedicInteractiveText $UI;Write-Host $t.pasteHelp
    $lines=New-Object 'System.Collections.Generic.List[string]';$size=0
    for($i=0;$i -lt 2048;$i++){
        $line=Read-Host $t.line
        if($line -ceq 'CANCEL'){return}
        if($line -ceq 'END'){
            if(-not $lines.Count){return}
            return ConvertFrom-ADBMedicRequestBytes ([Text.UTF8Encoding]::new($false).GetBytes(($lines -join "`n"))) $CaseId
        }
        $size+=[Text.Encoding]::UTF8.GetByteCount($line)+1
        if($size -gt 65536){Stop-ADBMedicRequest 'size' 'request'}
        $lines.Add($line)
    }
    Stop-ADBMedicRequest 'size' 'request'
}

function Show-ADBMedicRequestFilePicker {
    param([string]$Title)
    if(-not [Environment]::UserInteractive -or $env:CI -eq 'true'){return [pscustomobject]@{Status='unavailable';Path=$null}}
    $runspace=$null;$picker=$null
    try{
        $runspace=[System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace();$runspace.ApartmentState='STA';$runspace.ThreadOptions='ReuseThread';$runspace.Open()
        $picker=[PowerShell]::Create();$picker.Runspace=$runspace
        # Constant UI script only. Model/request text is never passed to AddScript.
        $dialogScript={param($Caption)
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $dialog=New-Object Windows.Forms.OpenFileDialog
            try{$dialog.Title=$Caption;$dialog.Filter='JSON (*.json)|*.json';$dialog.Multiselect=$false;$dialog.CheckFileExists=$true
                if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$dialog.FileName}else{''}
            }finally{$dialog.Dispose()}
        }
        [void]$picker.AddScript($dialogScript.ToString()).AddArgument($Title)
        $result=@($picker.Invoke())
        if($picker.HadErrors){throw 'Picker unavailable.'}
        if($result.Count -eq 1 -and $result[0]){return [pscustomobject]@{Status='selected';Path=[string]$result[0]}}
        return [pscustomobject]@{Status='cancelled';Path=$null}
    }catch{return [pscustomobject]@{Status='unavailable';Path=$null}}
    finally{if($picker){$picker.Dispose()};if($runspace){$runspace.Dispose()}}
}

function Get-ADBMedicDownloadsDirectory {
    $shell=$null;$folder=$null
    try{
        $shell=New-Object -ComObject Shell.Application -ErrorAction Stop
        $folder=$shell.Namespace('shell:Downloads')
        if($folder -and $folder.Self.Path){return [string]$folder.Self.Path}
    }catch{}finally{if($folder){[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($folder)};if($shell){[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)}}
    return Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
}

function Select-ADBMedicDownloadedRequest {
    param([string]$UI='en')
    $t=Get-ADBMedicInteractiveText $UI;$path=Get-ADBMedicDownloadsDirectory
    if(-not $path -or -not (Test-Path -LiteralPath $path -PathType Container)){Write-Host $t.noDownloads;return}
    $path=Assert-ADBMedicLocalDirectory $path
    $files=@(Get-ChildItem -LiteralPath $path -Filter 'followup-request*.json' -File|Where-Object {$_.Name -match '^followup-request(?: \([1-9][0-9]*\))?\.json$' -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object LastWriteTimeUtc -Descending)
    if(-not $files.Count){Write-Host $t.noDownloads;return}
    for($i=0;$i -lt $files.Count;$i++){Write-Host (($i+1).ToString()+'. '+$files[$i].Name+' — '+$files[$i].LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))}
    $choice=Read-Host $t.downloadChoice;$index=0
    if([int]::TryParse($choice,[ref]$index) -and $index -gt 0 -and $index -le $files.Count){return $files[$index-1].FullName}
}

function Import-ADBMedicInteractiveRequest {
    param([string]$CaseId,[string]$UI='en')
    $t=Get-ADBMedicInteractiveText $UI
    Write-Host $t.file;Write-Host $t.paste;Write-Host $t.downloads
    $choice=(Read-Host $t.import).Trim();$path=$null
    switch($choice){
        '1' {$selected=Show-ADBMedicRequestFilePicker $t.picker
            if($selected.Status -eq 'selected'){$path=$selected.Path}
            elseif($selected.Status -eq 'unavailable'){Write-Host $t.pickerUnavailable;$path=Read-Host $t.path}
        }
        '2' {return Read-ADBMedicPastedRequest $CaseId $UI}
        '3' {$path=Select-ADBMedicDownloadedRequest $UI}
        '' {return}
        default {Write-Host $t.invalid;return}
    }
    if($path){return Read-ADBMedicRequestFile $path $CaseId}
}

function Get-ADBMedicLocalAdb {
    $command=Get-Command adb -ErrorAction SilentlyContinue
    if($command){if($command.Source){return $command.Source}else{return $command.Name}}
    $path=Join-Path $env:LOCALAPPDATA 'ADBMedic\tools\platform-tools\adb.exe'
    if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    Stop-ADBMedicRequest 'adb' 'case'
}

function Invoke-ADBMedicConfirmedFollowup {
    param([string]$Session,$Imported,[string]$UI='en',[string]$Adb='')
    $Session=Assert-ADBMedicLocalDirectory $Session;$state=Get-ADBMedicCaseState $Session
    # Reparse at the shared boundary; both advanced CLI and menu use this function.
    $Imported=ConvertFrom-ADBMedicRequestBytes $Imported.OriginalBytes $state.case_id
    Assert-ADBMedicRequestNotReplayed $Session $state.case_id (Get-ADBMedicRequestFingerprint $Imported.Request)
    $t=Get-ADBMedicInteractiveText $UI;$ru=$UI -eq 'ru'
    $labels=if($ru){@{cpu_threads='Загрузка потоков выбранного процесса';process_cpu_times='Изменение CPU-счётчиков выбранного процесса';camera_clients='Состояние камеры и её клиенты';sensor_clients='Состояние датчиков и их клиенты';wakelock_delta='Два снимка wake locks и статистики батареи';jobs_alarms='Задания и будильники приложений';battery_timeline='История состояния батареи';power_sleep_state='Питание, сон и Doze';gnss_activity='Состояние службы геолокации';radio_network_state='Мобильная сеть, Wi-Fi и сетевые счётчики';thermal_history='Данные службы температур'}}else{@{cpu_threads='Thread CPU samples for the selected process';process_cpu_times='CPU counter samples for the selected process';camera_clients='Camera state and clients';sensor_clients='Sensor state and clients';wakelock_delta='Two wake-lock/battery-stat snapshots';jobs_alarms='Application jobs and alarms';battery_timeline='Battery state timeline';power_sleep_state='Power, sleep and Doze state';gnss_activity='Location service state';radio_network_state='Cellular, Wi-Fi and network counters';thermal_history='Thermal service data'}}
    $labels['targeted_logcat']=if($ru){'Последние 200 системных/crash-записей выбранного процесса'}else{'Last 200 system/crash log records for the selected process'}
    foreach($check in $Imported.Request.checks){
        Write-Host ('- '+$labels[$check.id]+' ['+$check.id+']')
        if($null -ne $check.target_pid){Write-Host ('  PID: '+$check.target_pid)}
        if($check.id -in @('gnss_activity','radio_network_state','targeted_logcat')){Write-Host $t.sensitive}
        if($check.id -eq 'wakelock_delta'){Write-Host $(if($ru){'  USB остаётся подключённым; это не измерение разряда в простое.'}else{'  USB stays connected; this is not an idle-discharge measurement.'})}
    }
    Write-Host $t.notice
    if((Read-Host $t.confirm) -notmatch '^(y|yes|да|д)$'){Write-Host $t.cancelled;return}
    if(-not $Adb){$Adb=Get-ADBMedicLocalAdb}
    if(-not (Get-Command $Adb -ErrorAction SilentlyContinue)){Stop-ADBMedicRequest 'adb' 'case'}
    Write-Host $t.reconnect
    $serial=Select-ADBMedicAdbDevice -Adb $Adb -UI $UI
    if(-not $serial){return}
    return Invoke-ADBMedicFollowupRound $Session $Imported.Request $Adb $serial -RequestBytes $Imported.Bytes -OriginalRequestBytes $Imported.OriginalBytes
}

function Get-ADBMedicSavedBundle {
    param([string]$Directory,[string]$CaseId)
    $exports=Join-Path $Directory 'exports'
    if(-not (Test-Path -LiteralPath $exports)){return}
    $exports=Assert-ADBMedicLocalDirectory $exports
    $manifest=Read-ADBMedicControlJson (Join-Path $exports 'manifest.json')
    if($manifest.schema -cne 'adbmedic.manifest.v1' -or $manifest.case_id -cne $CaseId -or $manifest.collectorVersion -notmatch '^0\.[23]\.'){throw 'Incompatible case format.'}
    $name=if($manifest.round_id){if($manifest.round_id -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid round identity.'};'ADBMedic-followup-'+$manifest.round_id+'.zip'}else{'ADBMedic-report.zip'}
    $zipPath=Join-Path $exports $name;$file=Get-Item -LiteralPath $zipPath -Force
    if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Invalid saved ZIP.'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($zipPath)
    try{
        $entries=@($zip.Entries|Where-Object FullName -CEQ 'manifest.json')
        if($entries.Count -ne 1 -or $entries[0].Length -gt 1048576){throw 'Invalid saved ZIP manifest.'}
        $reader=New-Object IO.StreamReader($entries[0].Open())
        try{$inside=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}
        if($inside.case_id -cne $CaseId -or $inside.schema -cne $manifest.schema -or $inside.round_id -cne $manifest.round_id){throw 'Saved ZIP belongs to another case.'}
    }finally{$zip.Dispose()}
    $starter=New-ADBMedicStartPrompt $(if($manifest.answerLanguage -like 'ru*'){'ru'}else{'en'}) ([Globalization.CultureInfo]::GetCultureInfo($manifest.answerLanguage))
    return [pscustomobject]@{Ready=$true;Directory=$exports;ArchiveName=$name;CaseId=$CaseId;StarterPrompt=$starter;Created=[DateTimeOffset]$manifest.created}
}

function Get-ADBMedicSavedCases {
    param([string]$DataRoot)
    if(-not (Test-Path -LiteralPath $DataRoot -PathType Container)){return}
    $DataRoot=Assert-ADBMedicLocalDirectory $DataRoot
    foreach($directory in Get-ChildItem -LiteralPath $DataRoot -Directory -Filter 'session-*'){
        try{
            $path=Assert-ADBMedicLocalDirectory $directory.FullName
            $state=Read-ADBMedicControlJson (Join-Path $path 'case.json')
            if($state.schema -cne 'adbmedic.case.v1' -or $state.case_id -cnotmatch '^CASE-[a-f0-9]{32}$' -or $state.round_id -or $state.interactiveVersion -gt 1){throw 'Invalid or incompatible case.'}
            if(-not $state.target -or $state.target.adbSerial -isnot [string] -or -not $state.target.adbSerial -or $state.target.fingerprintSha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Case binding is missing.'}
            if(-not $state.answerLocale -or -not $state.created){throw 'Incomplete case metadata.'}
            [void][Globalization.CultureInfo]::GetCultureInfo([string]$state.answerLocale)
            $created=[DateTimeOffset]$state.created
            $bundles=@();$baseline=Get-ADBMedicSavedBundle $path $state.case_id
            if($baseline){$bundles+=,$baseline}
            $parent=Join-Path $path 'followups';$interrupted=$false
            if(Test-Path -LiteralPath $parent){
                $parent=Assert-ADBMedicLocalDirectory $parent
                foreach($round in Get-ChildItem -LiteralPath $parent -Directory){
                    if($round.Name -cnotmatch '^[a-f0-9]{32}$'){continue}
                    $roundPath=Assert-ADBMedicLocalDirectory $round.FullName
                    try{$bundle=Get-ADBMedicSavedBundle $roundPath $state.case_id;if($bundle){$bundles+=,$bundle}else{$interrupted=$true}}catch{$interrupted=$true}
                }
            }
            [pscustomobject]@{Valid=$true;Directory=$path;State=$state;Created=$created;Bundle=($bundles|Sort-Object Created -Descending|Select-Object -First 1);Interrupted=$interrupted}
        }catch{[pscustomobject]@{Valid=$false;Directory=$directory.FullName;State=$null;Created=[DateTimeOffset]::MinValue;Bundle=$null;Interrupted=$false}}
    }
}

function Select-ADBMedicResumeCase {
    param([string]$DataRoot,[string]$UI='en')
    $t=Get-ADBMedicInteractiveText $UI;$all=@(Get-ADBMedicSavedCases $DataRoot)
    $valid=@($all|Where-Object Valid|Sort-Object Created -Descending)
    if(@($all|Where-Object {-not $_.Valid}).Count){Write-Host $t.legacy}
    if(-not $valid.Count){return [pscustomobject]@{Action='new';Case=$null}}
    while($true){
        Write-Host $t.resume;Write-Host $t.other;Write-Host $t.new;Write-Host $t.exit
        $choice=(Read-Host $t.startup).Trim()
        switch($choice){
            '0' {return [pscustomobject]@{Action='exit';Case=$null}}
            '3' {return [pscustomobject]@{Action='new';Case=$null}}
            {$_ -in @('','1','2')} {
                $ambiguous=$valid.Count -gt 1 -and $valid[0].Created.UtcDateTime.Ticks -eq $valid[1].Created.UtcDateTime.Ticks
                if($choice -ne '2' -and -not $ambiguous){return [pscustomobject]@{Action='resume';Case=$valid[0]}}
                if($ambiguous){Write-Host $t.ambiguous}
                for($i=0;$i -lt $valid.Count;$i++){Write-Host (($i+1).ToString()+'. '+$valid[$i].Created.ToString('yyyy-MM-dd HH:mm:ss zzz')+' / '+$valid[$i].State.case_id.Substring(0,13))}
                $number=0;$answer=Read-Host $t.chooseCase
                if([int]::TryParse($answer,[ref]$number) -and $number -gt 0 -and $number -le $valid.Count){return [pscustomobject]@{Action='resume';Case=$valid[$number-1]}}
            }
            default {Write-Host $t.invalid}
        }
    }
}

function Show-ADBMedicCaseMenu {
    param([string]$Session,$Bundle,[string]$UI='en',[string]$Adb='')
    $Session=Assert-ADBMedicLocalDirectory $Session;$state=Get-ADBMedicCaseState $Session
    $t=Get-ADBMedicInteractiveText $UI
    if($Bundle -and $Bundle.Ready){Write-Host $Bundle.ArchiveName;Write-Host $t.copy;Write-Host $Bundle.StarterPrompt}else{Write-Host $t.missingZip}
    while($true){
        Write-Host $t.ready;Write-Host $t.report;Write-Host $t.folder;Write-Host $t.request
        if(-not $Bundle -or -not $Bundle.Ready){Write-Host $t.retry}
        Write-Host $t.exit;$choice=(Read-Host $t.menu).Trim()
        if($choice -in @('','0')){return}
        try{
            switch($choice){
                '1' {$path=if($Bundle -and $Bundle.Ready){Join-Path $Bundle.Directory 'REPORT.html'}else{Join-Path $Session 'REPORT.html'};try{Start-Process -FilePath $path|Out-Null}catch{Write-Warning $t.openFailed}}
                '2' {$path=if($Bundle -and $Bundle.Ready){$Bundle.Directory}else{$Session};try{Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$path+'"')|Out-Null}catch{Write-Warning $t.openFailed}}
                '3' {
                    $request=Import-ADBMedicInteractiveRequest $state.case_id $UI
                    if(-not $request){continue}
                    $next=Invoke-ADBMedicConfirmedFollowup $Session $request $UI $Adb
                    if($next){$Bundle=$next;Write-Host $Bundle.ArchiveName;Write-Host $t.attach;Write-Host $t.copy;Write-Host $Bundle.StarterPrompt}
                }
                '4' {
                    if($Bundle -and $Bundle.Ready){Write-Host $t.invalid;continue}
                    $language=if($state.answerLocale){$state.answerLocale}else{'en-US'}
                    $Bundle=& (Join-Path $PSScriptRoot 'Package-ADBMedic.ps1') -Session $Session -Language $language -PassThru
                    Write-Host $Bundle.ArchiveName;Write-Host $t.copy;Write-Host $Bundle.StarterPrompt
                }
                default {Write-Host $t.invalid}
            }
        }catch{Write-ADBMedicInteractiveError $_ $UI}
    }
}
