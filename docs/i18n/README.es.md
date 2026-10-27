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

Cuando el ZIP de diagnóstico esté listo, adjunta **ADBMedic-report.zip** a una IA de confianza y pide que siga las instrucciones. La IA investiga las causas, explica el consumo por aplicación real con valores, tipos de eventos y períodos, propone acciones y verifica el resultado. Si faltan datos, proporciona comandos ADB específicos de solo lectura con explicaciones. [Contrato de la IA](../../AI-ANALYST.md). La opción 2 abre la carpeta. Sin soporte ZIP, adjunta REPORT.md, facts.json, MANUAL-ANALYSIS-PROMPT.md y los archivos pertinentes de evidence.

La interfaz de diagnóstico actualmente admite ruso e inglés y elige el idioma según el idioma de pantalla de Windows. Para los demás idiomas se utiliza el inglés. No necesitas elegir un modo ni añadir parámetros al comando.

## ¿Ya descargaste el proyecto?

Copia el mensaje inicial mostrado al terminar y envíalo junto con el ZIP. También está en el informe y en **START-PROMPT.txt**, junto al ZIP y dentro de él. La IA responde por defecto en el idioma de Windows; una petición explícita de otro idioma en el chat tiene prioridad.

Abre PowerShell en la carpeta del proyecto y ejecuta:

```powershell
.\bootstrap.ps1
```

## Tus datos

El script lee los datos de diagnóstico y los guarda en tu equipo, en `%LOCALAPPDATA%\ADBMedic`. No cambia la configuración del teléfono ni envía datos de diagnóstico a la nube.

El ZIP es privado: conserva el problema descrito, modelo/Android, horas de captura, nombres reales de procesos y paquetes, UID/PID y diagnósticos detallados. Revísalo antes de compartirlo con la IA elegida. No lo publiques en GitHub. Los patrones conocidos de credenciales y claves privadas bloquean el empaquetado; no se garantiza detectar todos los secretos. No hay envíos automáticos ni ejecución automática de consejos. [Formato y límites](../SAFE-HANDOFF.md).

Probado con Windows PowerShell 5.1. Aún falta verificar una ejecución completa con un teléfono real.

[Guía para desarrolladores: pruebas, protección de Git y opciones avanzadas](../DEVELOPMENT.md) · [Licencia MIT](../../LICENSE)
