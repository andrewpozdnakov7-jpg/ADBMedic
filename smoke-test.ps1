$ErrorActionPreference='Stop'
$root=$PSScriptRoot
. (Join-Path $root 'scripts/Privacy.Core.ps1')
$sourceFiles=@(Get-PrivacyManifest ([IO.File]::ReadAllBytes((Join-Path $root 'source-manifest.json'))))
foreach($name in @($sourceFiles | Where-Object { $_.EndsWith('.ps1') })){
    $file=Get-Item -LiteralPath (Join-Path $root $name)
    $tokens=$null; $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if($errors.Count -ne 0){
        Write-Host ('Syntax validation failed for '+$file.Name)
        throw 'Syntax validation failed; check locally without sharing sensitive full paths.'
    }
}
. (Join-Path $root 'ADBMedic-Device.ps1')
$none=@(ConvertFrom-ADBMedicAdbDeviceList -Lines @('List of devices attached',''))
if($none.Count -ne 0){throw 'Empty ADB output parser failure'}
$test=@(ConvertFrom-ADBMedicAdbDeviceList -Lines @('SERIAL_TEST_001    unauthorized', 'SERIAL_TEST_002 device product:synthetic'))
if($test.Count -ne 2){throw 'ADB state parser failure'}
if($test[0].State -ne 'unauthorized' -or $test[1].State -ne 'device'){throw 'ADB status parser failure'}
. (Join-Path $root 'ADBMedic-Locale.ps1')
if((Resolve-ADBMedicLanguage -Language 'ru-RU').UI -ne 'ru'){throw 'Russian locale failure'}
if((Resolve-ADBMedicLanguage -Language 'en-US').UI -ne 'en'){throw 'English locale failure'}
$stage=Join-Path $env:TEMP ('ADBMedic-synthetic-test-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage) | Out-Null
try{
    $md=Join-Path $stage 'REPORT.md'
    [IO.File]::WriteAllText($md, '# Synthetic report'+[Environment]::NewLine+'**SAFE**'+[Environment]::NewLine+'<script>unsafe</script>', [Text.Encoding]::UTF8)
    & (Join-Path $root 'Show-ADBMedicReport.ps1') -InputFile $md -Language 'en-US' | Out-Null
    $html=[IO.File]::ReadAllText((Join-Path $stage 'REPORT.html'),[Text.Encoding]::UTF8)
    if($html.Contains('<script>unsafe</script>')){throw 'Unsafe HTML in preview'}
    if(-not $html.Contains('&lt;script&gt;')){throw 'Markup was not escaped'}
    foreach($language in @('en-US','ru-RU')){
        & (Join-Path $root 'Write-ADBMedicPreliminary.ps1') -Session $stage -Language $language -NoBrowser | Out-Null
        $report=[IO.File]::ReadAllText($md,[Text.Encoding]::UTF8)
        if($report.Contains('MANUAL-ANALYSIS-PROMPT.md')){throw 'Preliminary report suggests unavailable export'}
        $expected=if($language -eq 'ru-RU'){'Автоматическая отправка в облако отключена.'}else{'Automatic cloud uploads are disabled.'}
        if(-not $report.Contains($expected)){throw 'Preliminary report is missing the privacy hold'}
    }
    $blocked=$false
    try { & (Join-Path $root 'Package-ADBMedic.ps1') -Session $stage -Language 'en-US' | Out-Null }
    catch { $blocked=$true }
    if(-not $blocked){throw 'Privacy guard failed: raw ZIP export unexpectedly allowed'}
    if((Get-ChildItem -LiteralPath $stage -Filter '*.zip' -File).Count -gt 0){throw 'ZIP created despite privacy guard'}
    Write-Host 'Offline synthetic smoke tests: PASS'
}finally{
    try { if([IO.Directory]::Exists($stage)){[IO.Directory]::Delete($stage,$true)} }
    catch { Write-Warning 'Could not remove synthetic test directory.' }
}
& (Join-Path $root 'tests/Privacy.Tests.ps1')
