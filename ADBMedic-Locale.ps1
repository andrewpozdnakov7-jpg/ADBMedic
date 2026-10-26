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
            chooseMode='Локальный режим (Enter). Экспорт ZIP и облачный анализ временно отключены.'
            offline='Локальный режим: подключение к Codex не требуется.'
            missingCodex='Codex CLI не найден. Переключаюсь на локальный режим.'
            consentAI='Облачный анализ отключён до реализации проверенной очистки данных.'
            analyze='Облачный анализ временно недоступен.'
            report='Отчёт'
            zip='Экспорт ZIP отключён'
            zipWarning='Сырые диагностические данные могут содержать личную информацию. Не передавайте их в облако.'
            zipConfirm='Экспорт недоступен до реализации проверенной очистки данных.'
            missingAdb='ADB не найден. Скачать официальные Google Platform-Tools'
            installCodex='Установка Codex не требуется: облачный анализ временно отключён.'
            whatNext='Изучите локальный отчёт. Не отправляйте сырые данные в облако; безопасный экспорт пока недоступен.'
            failure='Облачный анализ и экспорт ZIP отключены. Доступен локальный отчёт.'
            none='Не обнаружено'
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
        chooseMode='Local mode (Enter). ZIP export and cloud analysis are temporarily disabled.'
        offline='Local mode: no Codex or AI network access is required.'
        missingCodex='Codex CLI not found. Switching to local mode.'
        consentAI='Cloud analysis is disabled until verified data sanitization is available.'
        analyze='Cloud analysis is temporarily unavailable.'
        report='Report'
        zip='ZIP export disabled'
        zipWarning='Raw diagnostics may contain personal information. Do not upload them to the cloud.'
        zipConfirm='Export is unavailable until verified data sanitization is implemented.'
        missingAdb='ADB is missing. Download official Google Platform-Tools'
        installCodex='Codex installation is not required: cloud analysis is temporarily disabled.'
        whatNext='Review the local report. Do not upload raw data; safe export is not available yet.'
        failure='Cloud analysis and ZIP export are disabled. The local report is available.'
        none='Not found'
    }
}
