# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · [Español](README.es.md) · [Português](README.pt.md) · **Français** · [简体中文](README.zh-CN.md)

Recueille des données de diagnostic Android et ouvre un rapport local. Fonctionne sous Windows sans droits administrateur.

## Démarrage

1. Connectez le téléphone en USB et activez le débogage USB sur celui-ci.
2. Ouvrez une fenêtre normale de **Windows PowerShell**.
3. Collez cette commande :

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

Confirmez l'installation et la collecte des données. Si ADB est absent, l'application vous proposera de le télécharger. Sur le téléphone, autorisez le débogage depuis cet ordinateur. À la fin, choisissez **1 — ouvrir le rapport** ou **2 — ouvrir son dossier**. Rien ne s'ouvre automatiquement ; appuyez sur Entrée pour terminer.

Quand l'application confirme que le ZIP sécurisé est prêt, joignez **ADBMedic-report.zip** à votre chat IA (ChatGPT, Claude ou autre) et demandez-lui de suivre les instructions incluses. L'archive contient les mesures et une demande de conclusions claires, d'étapes détaillées et de suivi. L'option 2 ouvre le dossier du ZIP. Si le chat ne lit pas les ZIP, extrayez-le et joignez REPORT.md, facts.json et MANUAL-ANALYSIS-PROMPT.md.

L'interface de diagnostic prend actuellement en charge le russe et l'anglais et choisit la langue selon la langue d'affichage de Windows. Pour les autres langues, l'anglais est utilisé. Aucun mode ni paramètre de commande à choisir.

## Le projet est déjà téléchargé ?

Ouvrez PowerShell dans le dossier du projet et lancez :

```powershell
.\bootstrap.ps1
```

## Vos données

Le script lit les données de diagnostic et les enregistre sur votre ordinateur dans `%LOCALAPPDATA%\ADBMedic`. Il ne modifie pas les paramètres du téléphone et n'envoie pas de données de diagnostic dans le cloud.

Le rapport local est privé. Partagez uniquement le ZIP préparé : il contient des mesures numériques validées et des étiquettes de processus propres à cette session, sans identifiants ni journaux bruts. Si la validation échoue, aucune archive à partager n'est créée. Aucun diagnostic ni envoi vers une IA n'est automatique ; le chat choisi effectue l'analyse. [Format d'export et limites](../SAFE-HANDOFF.md).

Testé avec Windows PowerShell 5.1. Une exécution complète avec un téléphone réel reste à vérifier.

[Guide de développement : tests, protection Git et options avancées](../DEVELOPMENT.md) · [Licence MIT](../../LICENSE)
