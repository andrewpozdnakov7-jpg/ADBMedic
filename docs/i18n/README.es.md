# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · **Español** · [Português](README.pt.md) · [Français](README.fr.md) · [简体中文](README.zh-CN.md)

Recopila datos de diagnóstico de Android y abre un informe local. Funciona en Windows sin permisos de administrador.

## Primeros pasos

1. Conecta el teléfono por USB y activa la depuración USB en él.
2. Abre una ventana normal de **Windows PowerShell**.
3. Pega este comando:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

Confirma la instalación y la recopilación de datos. Si falta ADB, la aplicación ofrecerá descargarlo. En el teléfono, autoriza la depuración desde este equipo. El informe se abrirá en el navegador al finalizar.

La interfaz de diagnóstico actualmente admite ruso e inglés y elige el idioma según el idioma de pantalla de Windows. Para los demás idiomas se utiliza el inglés. No necesitas elegir un modo ni añadir parámetros al comando.

## ¿Ya descargaste el proyecto?

Abre PowerShell en la carpeta del proyecto y ejecuta:

```powershell
.\bootstrap.ps1
```

## Tus datos

El script lee los datos de diagnóstico y los guarda en tu equipo, en `%LOCALAPPDATA%\ADBMedic`. No cambia la configuración del teléfono ni envía datos de diagnóstico a la nube.

Por ahora, el informe resume los datos recopilados; el diagnóstico automático aún no está disponible. El envío de datos a una IA y la exportación de diagnósticos en ZIP están desactivados. Los archivos locales pueden contener información personal; no los publiques.

Probado con Windows PowerShell 5.1. Aún falta verificar una ejecución completa con un teléfono real.

[Guía para desarrolladores: pruebas, protección de Git y opciones avanzadas](../DEVELOPMENT.md) · [Licencia MIT](../../LICENSE)
