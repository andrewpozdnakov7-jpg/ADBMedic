[CmdletBinding()]
param([string]$Case='',[string]$Request='')
$ErrorActionPreference='Stop'
try{
    . (Join-Path $PSScriptRoot 'ADBMedic-Handoff.ps1')
    . (Join-Path $PSScriptRoot 'ADBMedic-Followup.ps1')
    . (Join-Path $PSScriptRoot 'ADBMedic-Device.ps1')
    if(-not $Case){$Case=Read-Host 'Case folder / Папка исходной сессии'}
    if(-not $Request){$Request=Read-Host 'Path to followup-request.json / Путь к запросу ИИ'}
    $Case=Assert-ADBMedicLocalDirectory $Case
    $state=Get-ADBMedicCaseState $Case
    $requestObject=Read-ADBMedicControlJson $Request
    $plan=ConvertTo-ADBMedicFollowupPlan $requestObject $state.case_id
    Write-Host ('Case / Случай: '+$state.case_id)
    foreach($check in $plan){Write-Host ($check.id+'; supported='+$check.supported+'; samples='+$check.repeat);if($check.note){Write-Host $check.note}}
    Write-Host 'Private diagnostic data stays local. No upload. / Личные диагностические данные остаются локально. Отправки нет.'
    if((Read-Host 'Run these read-only checks? / Выполнить эти проверки? [y/N]') -notmatch '^(y|yes|да|д)$'){return}
    $adbCommand=Get-Command adb -ErrorAction SilentlyContinue
    $adb=if($adbCommand){$adbCommand.Source}else{Join-Path $env:LOCALAPPDATA 'ADBMedic\tools\platform-tools\adb.exe'}
    if(-not $adb){throw 'ADB unavailable.'}
    $serial=Select-ADBMedicAdbDevice -Adb $adb -UI $(if($state.answerLocale -like 'ru*'){'ru'}else{'en'})
    if(-not $serial){return}
    $bundle=Invoke-ADBMedicFollowupRound $Case $requestObject $adb $serial
    Write-Host ('ZIP: '+(Join-Path $bundle.Directory $bundle.ArchiveName))
    Write-Host 'Attach this ZIP to the SAME AI conversation. / Передайте этот ZIP в ТОТ ЖЕ чат ИИ.'
    Write-Host $bundle.StarterPrompt
}catch{
    Write-Warning 'Follow-up not completed. Check case/request fields, matching device/build, ADB access and local storage. Existing evidence is retained. / Дополнительная проверка не завершена: проверьте запрос, исходную сессию, устройство, ADB и свободное место. Данные сохранены.'
    exit 1
}
