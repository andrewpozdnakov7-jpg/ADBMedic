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

Quand le ZIP de diagnostic est prêt, joignez **ADBMedic-report.zip** à une IA de confiance et demandez-lui de suivre les instructions. Elle recherche les causes, explique la consommation par application réelle avec valeurs, types d'événements et périodes, propose des actions et vérifie le résultat. Si des données manquent, elle fournit des commandes ADB ciblées en lecture seule avec explications. [Contrat de l'IA](../../AI-ANALYST.md). L'option 2 ouvre le dossier. Sans prise en charge ZIP, joignez REPORT.md, facts.json, MANUAL-ANALYSIS-PROMPT.md et les fichiers utiles de evidence.

L'interface de diagnostic prend actuellement en charge le russe et l'anglais et choisit la langue selon la langue d'affichage de Windows. Pour les autres langues, l'anglais est utilisé. Aucun mode ni paramètre de commande à choisir.

## Le projet est déjà téléchargé ?

Copiez le message de départ affiché après la collecte et envoyez-le avec le ZIP. Il figure aussi dans le rapport et dans **START-PROMPT.txt**, à côté du ZIP et à l'intérieur. L'IA répond par défaut dans la langue de Windows ; une demande explicite d'une autre langue dans le chat est prioritaire.

Ouvrez PowerShell dans le dossier du projet et lancez :

```powershell
.\bootstrap.ps1
```

## Vos données

Le script lit les données de diagnostic et les enregistre sur votre ordinateur dans `%LOCALAPPDATA%\ADBMedic`. Il ne modifie pas les paramètres du téléphone et n'envoie pas de données de diagnostic dans le cloud.

Le ZIP est privé : plainte, modèle/Android, heures de collecte, vrais noms de processus et paquets, UID/PID et diagnostics détaillés sont conservés. Examinez-le avant de le transmettre à l'IA choisie. Ne le publiez pas sur GitHub. Les motifs connus de secrets et clés privées bloquent l'archive, sans garantie de détecter tous les secrets. Aucun envoi ni conseil n'est exécuté automatiquement. [Format et limites](../SAFE-HANDOFF.md).

Testé avec Windows PowerShell 5.1. Une exécution complète avec un téléphone réel reste à vérifier.

[Guide de développement : tests, protection Git et options avancées](../DEVELOPMENT.md) · [Licence MIT](../../LICENSE)
