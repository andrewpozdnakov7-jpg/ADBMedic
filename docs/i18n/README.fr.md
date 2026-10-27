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

Confirmez l'installation et la collecte des données. Si ADB est absent, l'application vous proposera de le télécharger. Sur le téléphone, autorisez le débogage depuis cet ordinateur. Le rapport s'ouvrira dans le navigateur à la fin de la collecte.

L'interface de diagnostic prend actuellement en charge le russe et l'anglais et choisit la langue selon la langue d'affichage de Windows. Pour les autres langues, l'anglais est utilisé. Aucun mode ni paramètre de commande à choisir.

## Le projet est déjà téléchargé ?

Ouvrez PowerShell dans le dossier du projet et lancez :

```powershell
.\bootstrap.ps1
```

## Vos données

Le script lit les données de diagnostic et les enregistre sur votre ordinateur dans `%LOCALAPPDATA%\ADBMedic`. Il ne modifie pas les paramètres du téléphone et n'envoie pas de données de diagnostic dans le cloud.

Pour le moment, le rapport résume les données recueillies ; le diagnostic automatique n'est pas encore disponible. L'envoi de données à une IA et l'export des diagnostics en ZIP sont désactivés. Les fichiers locaux peuvent contenir des informations personnelles ; ne les publiez pas.

Testé avec Windows PowerShell 5.1. Une exécution complète avec un téléphone réel reste à vérifier.

[Guide de développement : tests, protection Git et options avancées](../DEVELOPMENT.md) · [Licence MIT](../../LICENSE)
