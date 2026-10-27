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

Confirma la instalación y la recopilación de datos. Si falta ADB, la aplicación ofrecerá descargarlo. En el teléfono, autoriza la depuración desde este equipo. Al finalizar, elige **1 — abrir el informe** o **2 — abrir su carpeta**. Nada se abre automáticamente; pulsa Enter para terminar.

Cuando la aplicación confirme que el ZIP seguro está listo, adjunta **ADBMedic-report.zip** a tu chat de IA (ChatGPT, Claude u otro) y pide que siga las instrucciones incluidas. Contiene mediciones y una solicitud de conclusiones claras, pasos detallados y seguimiento. La opción 2 abre la carpeta del ZIP. Si el chat no puede leer ZIP, extráelo y adjunta REPORT.md, facts.json y MANUAL-ANALYSIS-PROMPT.md.

La interfaz de diagnóstico actualmente admite ruso e inglés y elige el idioma según el idioma de pantalla de Windows. Para los demás idiomas se utiliza el inglés. No necesitas elegir un modo ni añadir parámetros al comando.

## ¿Ya descargaste el proyecto?

Abre PowerShell en la carpeta del proyecto y ejecuta:

```powershell
.\bootstrap.ps1
```

## Tus datos

El script lee los datos de diagnóstico y los guarda en tu equipo, en `%LOCALAPPDATA%\ADBMedic`. No cambia la configuración del teléfono ni envía datos de diagnóstico a la nube.

El informe local es privado. Comparte solo el ZIP preparado: contiene mediciones numéricas validadas y etiquetas de procesos válidas para esta sesión, sin identificadores ni registros originales. Si falla la validación, no se crea un ZIP para compartir. No se realiza un diagnóstico ni un envío a IA automáticamente; el análisis lo hace el chat que elijas. [Formato de exportación y límites](../SAFE-HANDOFF.md).

Probado con Windows PowerShell 5.1. Aún falta verificar una ejecución completa con un teléfono real.

[Guía para desarrolladores: pruebas, protección de Git y opciones avanzadas](../DEVELOPMENT.md) · [Licencia MIT](../../LICENSE)
