# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · **Español** · [Português](README.pt.md) · [Français](README.fr.md) · [简体中文](README.zh-CN.md)

¿El teléfono se descarga rápido o se calienta? ADBMedic prepara un informe para una IA de confianza, que puede ayudarte a investigar y decidir qué hacer.

Necesitas **un teléfono Android, un ordenador con Windows y un cable USB que transfiera datos**. No hace falta instalar una aplicación en el teléfono.

## 1. Prepara el teléfono

1. Abre **Ajustes → Acerca del teléfono → Número de compilación**. Puede estar en **Información de software**. Tócalo **7 veces** e introduce el PIN del teléfono si se solicita.
2. Busca **Opciones para desarrolladores** y activa **Depuración USB**. Los nombres varían; usa el buscador de Ajustes si hace falta.
3. Desbloquea el teléfono y conéctalo por USB a tu propio ordenador.

## 2. Ejecuta en el ordenador

Abre Inicio, escribe **Windows PowerShell** y ábrelo normalmente. No necesitas permisos de administrador.

Copia este comando, pégalo en PowerShell y pulsa **Enter**:

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

- Confirma la instalación y la recopilación con **y**, luego Enter. Si ofrece descargar una herramienta necesaria, acepta también.
- Mira el teléfono: si aparece **¿Permitir depuración USB?**, pulsa **Permitir** para tu ordenador.
- Describe el problema, por ejemplo: «La batería baja mucho durante la noche». Espera a que termine.

## 3. Envía el resultado a tu IA

1. Elige **2** en PowerShell para abrir la carpeta del informe. La opción **1** permite ver el informe.
2. Adjunta **ADBMedic-report.zip** a ChatGPT, Claude u otra IA de confianza.
3. Pega el mensaje inicial mostrado en PowerShell. También está en **START-PROMPT.txt**, junto al ZIP.

La IA debe explicar las observaciones, proponer pasos o pedir una comprobación adicional concreta. Responderá por defecto en el idioma de Windows; puedes pedir otro.

**¿No encuentra el teléfono?** Desbloquéalo, comprueba el permiso de depuración y prueba otro cable de datos o puerto USB. Si no se creó el ZIP, conserva el mensaje de error; no comprimas toda la carpeta por tu cuenta.

El informe contiene información privada del teléfono y las aplicaciones. El script no envía nada automáticamente. Comparte el ZIP solo con la IA elegida, no en GitHub. Después puedes desactivar la depuración USB. La interfaz del script está en ruso o inglés.

Si la IA pide más mediciones, siga las [instrucciones de comprobación local](../../agent/investigation-rules.md#running-a-follow-up-request-on-windows).

<details>
<summary>¿Ya descargaste el proyecto?</summary>

Abre PowerShell en la carpeta del proyecto y ejecuta:

```powershell
.\bootstrap.ps1
```

</details>

[Detalles técnicos y desarrollo](../DEVELOPMENT.md) · [Licencia MIT](../../LICENSE)
