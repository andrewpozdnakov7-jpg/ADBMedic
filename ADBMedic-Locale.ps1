# Shared locale and UI text for Windows PowerShell 5.1 and PowerShell 7.
# English is the fallback interface language; Codex can answer in any Windows UI locale.
function Resolve-ADBMedicLanguage {
    [CmdletBinding()]
    param([string]$Language = 'auto', [string]$Session = '')
    $locale = $Language
    if ([string]::IsNullOrWhiteSpace($locale) -or $locale -ieq 'auto') {
        $saved = $null
        if ($Session) {
            $state = Join-Path $Session 'locale.json'
            if (Test-Path -LiteralPath $state) {
                try { $saved = Get-Content -LiteralPath $state -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
            }
        }
        if ($saved -and $saved.locale) {
            $locale = [string]$saved.locale
        } else {
            $locale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        }
    }
    if ($locale -ieq 'english') { $locale = 'en-US' }
    if ($locale -ieq 'russian') { $locale = 'ru-RU' }
    if ([string]::IsNullOrWhiteSpace($locale) -or $locale -notmatch '^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$') {
        $locale = 'en-US'
    }
    $ui = if ($locale -match '^ru($|-)') {'ru'} else {'en'}
    [pscustomobject]@{
        Locale = $locale
        UI = $ui
        Requested = $Language
    }
}

function Get-ADBMedicText {
    [CmdletBinding()]
    param([string]$UI = 'en')
    if ($UI -eq 'ru') {
        return @{
            title='Диагностика Android'
            short='Краткий вывод'
            findings='Что собрано'
            actions='Следующие действия'
            confidence='Ограничения'
            preliminary='Предварительный локальный отчёт'
            preNotice='Это перечень собранных данных, а НЕ диагноз. Для поиска первопричины требуется анализ.'
            created='Создано'
            privacy='Эта страница локальная и не отправляет данные в интернет.'
            browser='Локальный отчёт'
            heroTitle='Что происходит с Android?'
            heroDesc='Измерения, факты и безопасные следующие шаги.'
            collect='Собирать диагностические данные? Они могут содержать личную информацию'
            symptom='Какую проблему исследуем? (необязательно)'
            noSymptom='Симптом не указан.'
            done='Готово'
            saved='Данные сохранены'
            collecting='Собираю диагностику Android...'
            preparing='Подготавливаю сводку и архив для ИИ...'
            chooseMode='Локальный режим (Enter). Экспорт ZIP и облачный анализ временно отключены.'
            offline='Локальный режим: подключение к Codex не требуется.'
            missingCodex='Codex CLI не найден. Переключаюсь на локальный режим.'
            consentAI='Облачный анализ отключён до реализации проверенной очистки данных.'
            analyze='Облачный анализ временно недоступен.'
            report='Отчёт'
            zip='Проверенный архив для чата'
            zipWarning='Сырые диагностические данные могут содержать личную информацию. Не передавайте их в облако.'
            zipConfirm='Подготовить проверенный ZIP с разрешёнными измерениями.'
            missingAdb='ADB не найден. Скачать официальные Google Platform-Tools'
            installCodex='Установка Codex не требуется: облачный анализ временно отключён.'
            whatNext='Передайте подготовленный ADBMedic-report.zip в чат нейросети вручную. Если ZIP не подготовлен, не отправляйте сырые данные или приватный отчёт.'
            failure='Автоматический облачный анализ отключён. Доступен приватный локальный отчёт; безопасный ZIP создаётся только после проверки.'
            none='Не обнаружено'
            reportReady='Отчёт собран. Что делаем дальше?'
            starterPrompt='Скопируйте этот промпт в чат вместе с ZIP (также сохранён в START-PROMPT.txt):'
            openReport='1. Открыть отчёт'
            openReportFolder='2. Посмотреть папку с отчётом'
            reportChoice='Введите 1 или 2; Enter — завершить'
            shareInstruction='Прикрепите ADBMedic-report.zip в чат нейросети, которой доверяете. Внутри реальные приложения, жалоба, подробная диагностика и инструкция для ИИ. Проверьте содержимое перед передачей. Выберите 2, чтобы найти ZIP. ИИ должен дать заключение, план действий и дополнительные ADB-команды при необходимости.'
            shareBlocked='Диагностический ZIP не подготовлен: отсутствует контекст, найдены возможные секреты или проверка не пройдена. Локальный отчёт доступен. Автоматическая отправка не выполняется.'
            invalidReportChoice='Выберите 1 или 2; для завершения нажмите Enter.'
            openFailed='Не удалось открыть выбранное окно. Можно повторить выбор или открыть папку с отчётом.'
        }
    }
    return @{
        title='Android Diagnostics'
        short='Short conclusion'
        findings='Collected evidence'
        actions='Next steps'
        confidence='Limitations'
        preliminary='Preliminary local report'
        preNotice='This is a collection summary, NOT a diagnosis. Root-cause analysis has not been performed.'
        created='Generated'
        privacy='This page is local and sends no information to the Internet.'
        browser='Local report'
        heroTitle='What is happening with Android?'
        heroDesc='Measurements, verified observations, and safe next steps.'
        collect='Collect diagnostics? They may contain personal information'
        symptom='What problem should be investigated? (optional)'
        noSymptom='No symptom was provided.'
        done='Done'
        saved='Evidence saved'
        collecting='Collecting Android diagnostics...'
        preparing='Preparing the evidence summary and AI archive...'
        chooseMode='Local mode (Enter). ZIP export and cloud analysis are temporarily disabled.'
        offline='Local mode: no Codex or AI network access is required.'
        missingCodex='Codex CLI not found. Switching to local mode.'
        consentAI='Cloud analysis is disabled until verified data sanitization is available.'
        analyze='Cloud analysis is temporarily unavailable.'
        report='Report'
        zip='Validated archive for AI chat'
        zipWarning='Raw diagnostics may contain personal information. Do not upload them to the cloud.'
        zipConfirm='Prepare a validated ZIP of allowed measurements.'
        missingAdb='ADB is missing. Download official Google Platform-Tools'
        installCodex='Codex installation is not required: cloud analysis is temporarily disabled.'
        whatNext='Attach the prepared ADBMedic-report.zip to your AI chat manually. If no ZIP was prepared, do not share raw data or the private report.'
        failure='Automatic cloud analysis is disabled. A private local report is available; a safe ZIP requires validation.'
        none='Not found'
        reportReady='Report collected. What would you like to do next?'
        starterPrompt='Copy this prompt into your chat with the ZIP (also saved as START-PROMPT.txt):'
        openReport='1. Open the report'
        openReportFolder='2. Open the report folder'
        reportChoice='Choose 1 or 2; Enter to finish'
        shareInstruction='Attach ADBMedic-report.zip to an AI chat you trust. It retains real applications, your complaint, detailed diagnostics and AI instructions. Review it before sharing. Choose 2 to find it. The AI should give a conclusion, action plan and focused follow-up ADB commands when needed.'
        shareBlocked='Diagnostic ZIP was not prepared: context is missing, possible secrets were found or validation failed. A local report is available. Nothing is uploaded automatically.'
        invalidReportChoice='Choose 1 or 2, or press Enter to finish.'
        openFailed='Could not open the selected window. Try again or open the report folder.'
    }
}
