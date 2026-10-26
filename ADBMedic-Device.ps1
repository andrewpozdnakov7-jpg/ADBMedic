# Device selection and helpful USB/ADB troubleshooting. Windows PowerShell 5.1 compatible.
function ConvertFrom-ADBMedicAdbDeviceList {
    [CmdletBinding()]
    param([string[]]$Lines = @())
    foreach($line in $Lines) {
        # adb devices -l: serial, status, optional model/product/transport metadata.
        $match=[regex]::Match($line,'^\s*(\S+)\s+(device|unauthorized|offline|recovery|sideload|no permissions)\b(.*)$')
        if($match.Success) {
            [pscustomobject]@{
                Serial=$match.Groups[1].Value
                State=$match.Groups[2].Value
                Details=$match.Groups[3].Value.Trim()
            }
        }
    }
}

function Select-ADBMedicAdbDevice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Adb,
        [ValidateSet('ru','en')][string]$UI='en'
    )
    while($true) {
        # Use "-l" so multi-device selection displays device model and transport details.
        $lines=@(& $Adb devices -l 2>&1 | ForEach-Object { "$_" })
        $status=$LASTEXITCODE
        if($status -ne 0) {
            Write-Host ''
            Write-Host 'ADB failed to enumerate devices.' -ForegroundColor Yellow
            # Do not echo vendor diagnostics or USB serials into shareable console logs.
            if($UI -eq 'ru') { Write-Host 'Проверьте установку ADB, USB-драйвер и подключение.' }
            else { Write-Host 'Check the ADB installation, USB driver and connection.' }
            $answer=Read-Host 'Enter = retry, Q = quit'
            if($answer -match '^(q|quit|exit)$'){return}
            continue
        }
        $devices=@(ConvertFrom-ADBMedicAdbDeviceList -Lines $lines)
        if($devices.Count -eq 1 -and $devices[0].State -eq 'device') {
            Write-Host 'ADB device connected and authorized.' -ForegroundColor Green
            return $devices[0].Serial
        }

        Write-Host ''
        if($UI -eq 'ru') {
            Write-Host 'ADBMedic: телефон пока не готов к диагностике.' -ForegroundColor Yellow
        } else {
            Write-Host 'ADBMedic: no Android device ready for diagnostics.' -ForegroundColor Yellow
        }
        if($devices.Count -gt 0) {
            Write-Host ''
            for($i=0;$i -lt $devices.Count;$i++) {
                $d=$devices[$i]
                $kind=if($d.Serial -match '^emulator-'){'Emulator'}else{'Android device'}
                Write-Host ('  '+($i+1)+'. '+$kind+' ['+$d.State+']')
            }
        }

        if($devices.Count -eq 0) {
            if($UI -eq 'ru') {
                Write-Host 'ADB установлен, но не обнаруживает подключённых устройств.'
                Write-Host '  1. Подключите телефон кабелем для передачи данных и разблокируйте экран.'
                Write-Host '  2. Включите в настройках разработчика "Отладка по USB".'
                Write-Host '  3. Проверьте, есть ли в диспетчере устройств Windows ADB Interface.'
                Write-Host '  4. При необходимости установите USB-драйвер производителя телефона.'
            }else{
                Write-Host 'ADB is installed, but no Android device was detected.'
                Write-Host '  1. Connect a data-capable USB cable and unlock the phone.'
                Write-Host '  2. Enable USB debugging in Developer options.'
                Write-Host '  3. Check Windows Device Manager for an ADB Interface.'
                Write-Host '  4. Install your phone manufacturer USB driver if needed.'
            }
        }else {
            foreach($d in $devices){
                if($d.State -eq 'unauthorized'){
                    if($UI -eq 'ru'){
                        Write-Host '  Ожидается разрешение USB-отладки: подтвердите RSA-запрос на телефоне.' -ForegroundColor Yellow
                    }else{
                        Write-Host '  USB debugging authorization required: accept the RSA prompt on the phone.' -ForegroundColor Yellow
                    }
                }elseif($d.State -eq 'offline'){
                    if($UI -eq 'ru'){
                        Write-Host '  Устройство offline: переподключите кабель, проверьте USB-отладку.' -ForegroundColor Yellow
                    }else{
                        Write-Host '  Device offline: reconnect the cable and check USB debugging.' -ForegroundColor Yellow
                    }
                }elseif($d.State -eq 'recovery' -or $d.State -eq 'sideload'){
                    if($UI -eq 'ru'){
                        Write-Host '  Устройство в служебном режиме. Загрузите обычную систему Android.' -ForegroundColor Yellow
                    }else{
                        Write-Host '  Device is in recovery/sideload. Boot normal Android first.' -ForegroundColor Yellow
                    }
                }
            }
        }
        Write-Host '  https://developer.android.com/studio/run/oem-usb'
        Write-Host ''

        $ready=@($devices | Where-Object {$_.State -eq 'device'})
        if($ready.Count -gt 0 -and $devices.Count -gt 1) {
            if($UI -eq 'ru') {
                Write-Host 'Подключено несколько устройств. Выберите номер нужного со статусом device.'
            }else{
                Write-Host 'Multiple devices found. Choose the number of the intended device in state "device".'
            }
            $answer=(Read-Host 'Number / Enter = rescan / Q = quit').Trim()
            if($answer -match '^\d+$'){
                $choice=[int]$answer
                if($choice -ge 1 -and $choice -le $devices.Count -and $devices[$choice-1].State -eq 'device'){
                    Write-Host 'ADB device selected and authorized.' -ForegroundColor Green
                    return $devices[$choice-1].Serial
                }
                Write-Host 'Selected device is not authorized/ready.' -ForegroundColor Yellow
                continue
            }
        }else{
            if($UI -eq 'ru'){
                $answer=(Read-Host 'После проверки подключения нажмите Enter, Q = выход').Trim()
            }else{
                $answer=(Read-Host 'Press Enter to check connection again, Q = quit').Trim()
            }
        }
        if($answer -match '^(q|quit|exit)$'){
            if($UI -eq 'ru'){Write-Host 'Диагностика отменена, телефон не изменён.'}
            else{Write-Host 'Cancelled. No device changes were made.'}
            return
        }
    }
}
