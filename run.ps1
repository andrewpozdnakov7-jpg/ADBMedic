# Public entry point: irm <this file's URL> | iex
& {
    $ErrorActionPreference='Stop'
    try {
        $source=Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/Install-ADBMedic.ps1' -TimeoutSec 30
        & ([scriptblock]::Create($source.Content.TrimStart([char]0xFEFF))) -Launch
    } catch {
        throw 'ADBMedic could not start. Check the Internet connection and try again.'
    }
}
