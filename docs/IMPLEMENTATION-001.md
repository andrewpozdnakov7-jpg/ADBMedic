# TASK-001 — Security, Privacy & GitHub

Дата: 2026-10-26. Среда: Windows PowerShell 5.1. Проверки только на синтетических данных.

## Область и результат

Проверен очищенный стартовый набор и все последующие исходники/конфигурации. Реальных приватных идентификаторов, диагностических материалов и секретов в отправляемом наборе не обнаружено. Реальные логи, устройства, чужие проекты и подписные ключи не читались. Публичная почта и имя `Andrew` разрешены владельцем. Стартовая папка и исходный handoff ZIP сохранены как ссылки, в Git они не включены.

Владелец разрешил проверенную публикацию исходников, ветки и PR. Локальная ветка TASK-001 основана на единственном начальном коммите созданного владельцем GitHub-репозитория. Прежняя история другого проекта не использовалась. Git identity настроена только локально; существующая атрибуция MIT сохранена. Force push, релизы и CI не применялись.

## Реализованная защита

- `source-manifest.json` — положительный список всех 40 публикуемых исходных файлов. Новые файлы требуют явного внесения и ручного ревью.
- `privacy-audit.ps1` и `scripts/Privacy.Core.ps1` — режимы Worktree, Staged, History. Проверяются именно index blobs и все достижимые деревья исходящей истории, включая промежуточные коммиты, сообщения и авторство. Чистая последняя версия не скрывает секрет из предка.
- Проверяются домашние пути, email/URL, IP/MAC, токены, присвоения паролей/ключей, приватные ключи/сертификаты, аппаратные идентификаторы/хеши, отпечатки и фрагменты диагностики. Неразрешённые файлы, бинарное содержимое, не-UTF-8, симлинки, junctions и submodules блокируются. Ошибка самого аудита также блокирует операцию.
- Исключения узкие: точная публичная почта, официальные ссылки, необходимые адреса выбранного репозитория, зарезервированные синтетические примеры. URL с посторонним query не скрывается allowlist. Неизвестные имена файлов в диагностике редактируются; совпавшие значения не печатаются.
- `.gitignore` дополнен вложенными приватными каталогами, диагностическими отчётами, архивами, бинарными артефактами и контейнерами ключей/сертификатов. Принудительно staged-файл всё равно блокируется независимо от ignore.
- `.githooks`: pre-commit проверяет рабочую копию и index; commit-msg — сообщение и публичное авторство; pre-push — всю историю каждого исходящего ref. `scripts/Install-GitHooks.ps1` включает hooks только в локальном репозитории.
- `scripts/Build-SafeSourceArchive.ps1` копирует только разрешённые файлы, проверяет копию, создаёт ZIP, повторно распаковывает его и независимо повторяет аудит и сравнение хешей. При находке архив не создаётся; существующий результат не перезаписывается. Это только архив исходников, не диагностики.

## Исправления и сохранённое поведение

- Устранены двойные UTF-8 BOM стартовых скриптов; исходники PowerShell содержат один BOM для корректной работы 5.1.
- Экспорт ZIP диагностики и облачный анализ остаются fail-closed. Заблокированные entry points больше не читают даже locale-файл приватной сессии.
- Согласие на сбор запрашивается до запуска ADB. Технический вывод запуска сервера и ошибок скрывается; путь профиля и USB-идентификатор не попадают в консоль. Ошибки генераторов отчёта/выборки имеют нейтральные сообщения; возвращаемые имена отчётов относительные.
- Локальный read-only сбор, приватная сессия и Markdown/HTML-отчёт сохранены. Операций root/reboot/kill/изменения пакетов, настроек или прошивки нет.
- Удалены устаревшие предложения загружать сырой ZIP из RU/EN интерфейса и отчёта. Автоматическая отправка диагностики отсутствует.
- Установщик исходников использует согласие и единый commit выбранного репозитория, не обновляет себя в фоне и не читает диагностику. Его обычный вывод больше не содержит абсолютный путь установки.
- Документация приведена к текущему разрешению на публикацию. Исторический отчёт об адаптации помечен как исторический. Работа над TASK-002 и новыми функциями диагностики не выполнялась.

## Результаты тестов

- `smoke-test.ps1`: PASS — разбор всех разрешённых PowerShell-файлов, синтетические ADB-строки, локали, HTML escaping, RU/EN предупреждения и блокировка ZIP; запускает также privacy suite.
- `tests/Privacy.Tests.ps1`: PASS, 61 проверка. Включает чистые/вредоносные синтетические строки, отсутствие утечки в выводе и код завершения CLI, корректный default source root, исключение приватных каталогов, отказ от junction/binary/неразрешённого имени, безопасную упаковку минимального и полного дерева, запрет архива при находке, точное распознавание публичного служебного committer GitHub и отказ для постороннего автора.
- Проверены реальные локальные hooks в изолированном синтетическом Git-репозитории: секрет в index при уже очищенной рабочей копии, принудительно добавленный искусственный signing-контейнер, staged symlink, секрет в промежуточном коммите под чистой вершиной. Pre-push блокирует такую историю; чистая история проходит в локальный тестовый bare-репозиторий. В этих тестах hooks не отключались.
- `tests/Runtime-Safety.Tests.ps1`: PASS, 69 проверок. Синтетические success/decline/missing-ADB/unauthorized/offline/no-device/enumeration-failure, сохранение локальных результатов, скрытие путей/серийников/ошибок и отсутствие сетевых, облачных и browser-вызовов. Реальная программа ADB не запускалась.
- `tests/Install-ADBMedic.Tests.ps1`: PASS, 39 проверок с mock-загрузками: согласие, один commit, режим запуска, параметры, повторная установка, сохранение локальных правок, плохая revision, ошибки/пустые/невалидные исходники, cleanup, кириллица и пробелы, отсутствие REST API и отказ при недоступной Git reference advertisement.
- Итог: 169 явных проверок трёх suites плюс smoke-проверки. Перед коммитом и push отдельно выполняются Worktree/Staged/History на точном отправляемом наборе. Первый push был автоматически заблокирован из-за слишком строгого распознавания служебного committer начального GitHub-коммита. Подтверждено, что это стандартные публичные метаданные сервиса, а не личная находка; добавлено точное исключение и отдельные положительный/отрицательный тесты. До исправления ничего не отправлялось.
- Публичная проверка загрузки после первой публикации обнаружила исчерпанную квоту анонимного GitHub REST API. Получение commit заменено на строгий разбор публичной Git reference advertisement без Git-клиента, токена или REST API. Все файлы по-прежнему загружаются из одного проверенного commit; ошибка протокола блокирует установку. Эта доработка оформляется отдельным PR без ослабления privacy-проверок.

## Ограничения

Regex и положительный список не доказывают отсутствие любого возможного имени, зашифрованного/закодированного секрета или узнаваемости кода по сходству. Изменения scanner, manifest и hooks требуют ручного ревью. Неизвестные форматы отклоняются; автоматической анонимизации Android-дампов здесь нет.

Hooks локальные: каждый новый checkout должен выполнить `scripts/Install-GitHooks.ps1`. Это не серверная защита и не защита ручной загрузки файлов через GitHub. Не обходить hooks и не публиковать при провале. CI/branch rules не настраивались.

PowerShell 7, реальные USB/OEM-устройства и независимый внешний аудит не проверялись. HTTPS-загрузка исходников/Platform-Tools не является независимой криптографической аттестацией; загрузка ADB требует отдельного согласия и в тестах не выполнялась.

## Проверка пользователем

После приёмки техническим руководителем: запустить команду из README в Windows PowerShell 5.1; проверить установку и RU/EN интерфейс. По отдельному решению подключить телефон, подтвердить read-only сбор и проверить открытие локального отчёта, отмену, несколько устройств и сообщения USB-ошибок. Не отправлять реальные файлы диагностики в чат, Git или облако. До TASK-002 ZIP и AI должны оставаться отключены.

Ссылки на итоговые GitHub-коммиты и PR предоставляются в финальном сообщении. После TASK-001 разработка останавливается до следующего задания.

## Дополнение 2026-10-27: простой пользовательский запуск

По запросу владельца README сокращён до инструкции для пользователя. Запуск из скачанной папки: `./bootstrap.ps1` без параметров. Язык выбирается по Windows, вопрос о режиме убран. Совместимые старые параметры не включают облачный анализ; обычный сценарий выполняет только локальный сбор и открывает отчёт. Он больше не вызывает намеренно заблокированный ZIP-экспортёр и не показывает ложное предупреждение о нём после успешного сбора.

Добавлен `run.ps1` для команды GitHub через `irm … | iex`; он запускает прежний установщик с обычными подтверждениями. Подробности разработки перенесены в `docs/DEVELOPMENT.md`. Положительный список обновлён до 43 файлов. Новые функции диагностики и TASK-002 не реализовывались.

Windows PowerShell 5.1: smoke/Privacy — PASS (61 проверка), Installer — PASS (41), Runtime safety — PASS (75), Public launch — PASS (4). Всего 181 явная проверка. Новые регрессии проверяют точный запуск bootstrap без аргументов, автоматический RU/EN по Windows, отсутствие выбора режима и запуск remote entry через Invoke-Expression без пользовательских флагов. Устройства, ADB и браузер в тестах подменены; реальный телефон не использовался. Перед публикацией повторяются Worktree/Staged/History и обычный branch/PR workflow.

## Дополнение 2026-10-27: международный README

Основной README переведён на английский. Сразу под названием добавлена навигация на родных языках: English, Русский, Español, Português, Français, 简体中文. Пять переводов находятся в `docs/i18n`, сохраняют одинаковую краткую структуру, команды и ограничения. Везде явно разделены языки документации и текущие русский/английский языки диагностического интерфейса. Положительный список обновлён до 48 исходных файлов; исполняемые скрипты не менялись.

Разовая проверка документации: PASS — шесть языковых меню, 42 локальные ссылки и 12 одинаковых блоков команд. Для этого изменения программные тесты не повторялись: изменены только документация и список разрешённых файлов. Перед публикацией выполнены проверки Worktree/Staged/History и обычные Git hooks.

## Дополнение 2026-10-27: меню и безопасная ручная передача в AI-чат

Владелец явно разрешил следующую стадию безопасного экспорта. Автоматическое открытие отчёта заменено меню: 1 — открыть приватный локальный отчёт, 2 — открыть папку с подготовленным архивом, Enter — завершить. При неудачном открытии окна меню остаётся доступным. Даже отдельный генератор отчёта по умолчанию не открывает браузер. `-NoBrowser` сохраняет неинтерактивное завершение для тестов и автоматизации.

Добавлен `ADBMedic-SafeExport.ps1`: проекция поддержанных измерений Toybox CPU, статистики батареи, питания и уровня нагрева в закрытую схему. Сохраняются короткие CPU-снимки, относительные периоды, оценки mAh и условные группы P. Связь меток с наблюдаемыми процессами находится только в локальном отчёте. Метки не являются стабильными идентификаторами между сессиями. Сырые логи, модель/серийники, UID/PID, ёмкость, абсолютное время и исходная жалоба не копируются в пакет. Неизвестные поля не пересылаются; отсутствие распознаваемых измерений, противоречивые периоды и некорректные значения блокируют подготовку ZIP.

ZIP содержит ровно REPORT.md, REPORT.html, facts.json и MANUAL-ANALYSIS-PROMPT.md. Проверка независимо разбирает закрытую схему, сравнивает канонические отчёт/инструкцию/HTML и затем повторяется после распаковки готового архива. Метаданные времени ZIP фиксированы. Исходные файлы и пути с reparse points отклоняются; действует ограничение размера входов, файлов и распаковки. Старый экспорт не перезаписывается. Только после всех проверок папка экспорта становится доступной пользователю.

Инструкция требует от нейросети понятного заключения, ссылок на измерения, оценки уверенности, 3–5 подробных обратимых шагов и шаблона обратной связи. При недостатке данных требуется конкретный следующий замер; запрещены выдуманные имена приложений, бездоказательные обвинения, разрушительные операции и запросы сырых логов. Учтены различие временных баз, оценочный характер mAh, номинальный интервал CPU и влияние USB-сбора. Передача архива выполняется только пользователем; автоматический облачный анализ и сырой экспорт остаются заблокированы.

В терминале и отчёте объясняется передача именно ADBMedic-report.zip в ChatGPT, Claude или другой подходящий чат. Если ZIP не подготовлен, выводится запрет на передачу сырых данных, без предложения отправить несуществующий архив. Инструкции синхронизированы во всех шести README; 48 локальных ссылок проверены. Установщик включает новый модуль (12 runtime-файлов). Положительный список исходников содержит 51 файл.

Windows PowerShell 5.1: Safe export — PASS, 127 проверок; Runtime safety/menu — PASS, 84; Installer — PASS, 41; Public launch — PASS, 4; Privacy — PASS, 61; smoke — PASS. Всего 317 явных проверок. Отрицательные случаи включают искусственные ключи, email, пути профиля и аппаратные номера в исходных данных, произвольный текст/поля в готовых документах, бинарные/нечисловые/нефинитные значения, неизвестные форматы, противоречивые периоды, ссылки и повторный экспорт. Проверено отсутствие автозапуска окон, ручное открытие пунктами меню, восстановление после ошибки окна, отсутствие автоматических upload-вызовов и честное сообщение при невозможности экспорта.

Ограничения: поддерживаются только описанные в SAFE-HANDOFF.md форматы и поля; OEM-варианты могут быть отклонены. Камера, сенсоры, сеть и native stacks не входят в передаваемые данные этой версии. Небольшое число снимков CPU не доказывает причину длительного разряда. Числовые шаблоны могут коррелировать с внешними наблюдениями; абсолютная анонимность и независимый внешний аудит не заявляются. PowerShell 7 и реальные устройства в разработческих проверках не использовались. Исходные форматы сверены с публичными исходниками AOSP; код сторонних реализаций не импортировался.

## Дополнение 2026-10-27: GitHub Actions CI/CD

Владелец отдельно разрешил CI/CD. Добавлен единственный разрешённый workflow `.github/workflows/ci.yml`: PR в main, push в main и ручной запуск. Две Windows-матрицы проверяют один и тот же набор тестов под PowerShell 5.1 и 7; сборка source ZIP зависит от обеих. Стабильный агрегирующий check `CI` не проходит при failed/skipped/cancelled обязательных заданиях.

Workflow использует read-only token, checkout без сохранения credentials, полную историю и точный head SHA PR вместо синтетического merge-коммита. Официальные checkout v7.0.1 и upload-artifact v7.0.2 закреплены проверенными SHA. Аудитор допускает только эти точные публичные action refs, а не любые хеши. Для `.github` сделано исключение только на один workflow с обязательным manifest entry; посторонняя автоматизация остаётся запрещённой.

После тестов создаётся архив только разрешённых исходников, затем он распаковывается и проверяется повторно. На main результат публикуется как Actions artifact на 7 дней. Диагностика, тестовые каталоги и персональные данные не загружаются. Релизы, custom secrets, изменения устройства и автоматическая передача в AI не включены.

Локальный Windows PowerShell 5.1: `scripts/Run-CI.ps1` — PASS, 322 проверки плюс smoke. Новые отрицательные случаи подтверждают отказ для непроверенного action SHA, workflow без manifest entry и других файлов автоматизации. Наборы тестов запускаются в отдельных процессах текущего PowerShell. Результаты реального GitHub runner и защита main проверяются при развёртывании; ссылки на run/PR приводятся в финальном сообщении. Подробности — в CI.md.

## Diagnostic AI handoff v2

The owner changed the product goal from anonymous numeric summaries to useful evidence for a manually chosen Android diagnostic AI. The shipped AI-ANALYST.md contract is embedded in each archive and summarized in the report: evidence-based conclusions, real application attribution, typed event counters and windows, reversible treatment, focused read-only ADB follow-up and detailed user feedback. GitHub is optional reference context; the contract works without browsing.

Package-ADBMedic.ps1 now produces schema 2: complaint, model/Android, collection times and allowlisted detailed text, including package/UID mapping, current battery state, alarms, jobs and idle state. Names and UID/PID remain useful. No unverified numeric battery balance is generated; original sections remain available for the AI to check. Capture intervals are distinct from historical counter windows. Unsupported OEM text remains inspectable and missing/failed commands are explicit.

Known credential/private-key patterns block the whole export; UTF-8, path/link, input-size, allowlist, overwrite and ZIP-content checks remain. This is intentionally private diagnostic evidence, not anonymized data or a guarantee of complete secret detection. Diagnostic archives remain excluded from Git and CI source artifacts. There are no automatic uploads, device changes or automatic execution of AI advice.

Windows PowerShell 5.1 targeted validation passed: handoff 57 assertions, runtime 97 assertions, smoke/privacy 66 assertions. Installer checks cover the two new pinned runtime files. Full Windows PowerShell 5.1/7 suites run on the final PR revision. Legacy schema-1 projection tests remain as compatibility coverage. Real-device collection and external-AI diagnostic quality require user acceptance with a newly collected archive; no old user report was modified or published.
## Starter prompt and full answer locale

The owner reauthorized publication after the local language/starter work. The diagnostic schema retains the full Windows display locale in language and the separate Russian/English collector interface in interfaceLanguage. Explicit language requests in the AI chat take precedence. Tested locales: Russian, English, French, Spanish, Brazilian Portuguese, Simplified Chinese and German; automatic French Windows selection retains French while the interface falls back to English.

After a completed archive, the console prints a short copyable starter prompt. Identical text appears in the report and START-PROMPT.txt beside and inside the ZIP. It names the attachment, directs the assistant to its full contract/evidence, requests diagnosis, app/counter/window explanations, treatment, follow-up commands and the correct answer language. Archive-access failure is explicit. A failed export prints no starter. No clipboard writes, automatic uploads or device actions are added.

Windows PowerShell 5.1 targeted validation: handoff 96 assertions and runtime safety 104 assertions passed. Full PS5.1/7 suites run in CI before protected merge. Real-device and external-AI acceptance remain user checks with a newly generated archive.
## Large diagnostic archives and actionable export errors

A user-authorized saved session exposed the former 16 MiB file cap. Diagnostic input and ZIP-entry validation now share a 64 MiB per-file / 128 MiB total limit. Evidence is never silently shortened. ZIP creation writes explicit standard forward-slash entries so nested evidence is portable across Windows PowerShell and AI attachment tools.

Export failures carry safe structured categories. The terminal distinguishes size limits, known-secret findings, text/link issues, missing context and occupied export directories; it prints only allowlisted filenames, never matched values or private paths. Secret/link/UTF-8/size/content gates remain enabled. Package mapping now queries the current Android user to avoid requesting inaccessible secondary profiles; old failed captures remain explicit rather than fabricated.

Windows PowerShell 5.1 targeted checks passed: handoff 108 assertions and runtime safety 108 assertions. Regression coverage includes a synthetic file above the old cap, no truncation, standard ZIP paths, oversized rejection, safe localized errors, retained secret blocking and current-user query scope. The supplied private session was repackaged locally and its complete battery text compared with the original. No phone commands were executed for that recovery; no private data, identifiers, paths or artifacts were added to the repository. Full PS5.1/7 CI is required before protected merge. The current-user query still needs confirmation on the user's phone.
## Prepared battery evidence, iteration 1

The user authorized deterministic first-stage processing for the AI. ADBMedic-Summary.ps1 streams recognized battery-statistics windows, retains section-local UID mAh estimates and partial-wakelock/job-timer-start/wakeup-alarm records, normalizes Android UID forms, maps packages from cited inventory or UID-scoped Apk records, and records original source line ranges. SUMMARY.md is embedded in the report and ZIP; facts.json.analysis version 1 retains parsed records, coverage and quality warnings. The starter/analyst instructions now use prepared evidence first and targeted raw reads afterward. The installer includes the new module.

Unknown windows/units, duplicate energy UIDs, ambiguous totals, bounds conflicts, unsupported rows and output limits remain explicit. No diagnosis, rates, per-call energy, overlapping-timer totals or guessed package names are generated. System component energy, CPU/network details and other services still need direct inspection when relevant. Extraction is bounded, and full raw input remains unchanged in the private archive. Each energy section has its own window and provenance; a ranking is only over parsed rows.

Local Windows PowerShell 5.1 checks passed: summary 26 assertions, handoff 114 assertions, runtime 108 assertions and installer 41 assertions. Synthetic regression cases cover separate/repeated windows and sections, original line numbers, unknown units/suffixes, partial extraction, zero vs missing, shared/cross-user UID mapping, timer semantics and output limits. The explicitly supplied saved session was processed locally into a separate prepared copy; the summary/JSON were substantially smaller than the raw dump and complete battery text was compared with the original. No private files, paths, values or device details are committed. Full PS5.1/7 CI is required before protected merge. Real-phone and external-AI diagnostic quality still require user acceptance.
## Beginner first-run READMEs

Rewrote the English README and five translations as three practical steps: enable USB debugging on the unlocked phone, run one command in ordinary Windows PowerShell, and attach the generated ZIP plus starter prompt to a chosen AI. Added the build-number/authorization steps, data-cable requirement and brief missing-device/missing-ZIP guidance. Kept privacy guidance concise and moved local-checkout startup into a collapsed optional section. Parser/schema details remain in linked technical documentation; the developer entry point now describes the current handoff rather than the historical numeric-only stage.

Documentation-only validation checked the identical remote command, required output filenames, optional local startup and all local Markdown links across six READMEs. No new runtime tests or phone commands were introduced; mandatory privacy hooks and repository CI remain required before merge.