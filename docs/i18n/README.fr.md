# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · [Español](README.es.md) · [Português](README.pt.md) · **Français** · [简体中文](README.zh-CN.md)

Le téléphone se décharge vite ou chauffe ? ADBMedic prépare un rapport pour une IA de confiance, qui peut vous aider à comprendre et proposer la suite.

Il faut **un téléphone Android, un ordinateur Windows et un câble USB permettant le transfert de données**. Aucune application à installer sur le téléphone.

## 1. Préparer le téléphone

1. Ouvrez **Paramètres → À propos du téléphone → Numéro de build**. Il peut être dans **Informations sur le logiciel**. Touchez-le **7 fois** et saisissez le code PIN du téléphone si demandé.
2. Trouvez **Options pour les développeurs** et activez **Débogage USB**. Les noms varient ; utilisez la recherche des Paramètres si nécessaire.
3. Déverrouillez le téléphone et reliez-le par USB à votre propre ordinateur.

## 2. Lancer sur l'ordinateur

Ouvrez Démarrer, saisissez **Windows PowerShell** et ouvrez-le normalement. Les droits administrateur ne sont pas nécessaires.

Copiez la commande, collez-la dans PowerShell et appuyez sur **Entrée** :

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

- Confirmez l'installation et la collecte avec **y**, puis Entrée. Si un outil nécessaire doit être téléchargé, confirmez aussi.
- Regardez le téléphone : si **Autoriser le débogage USB ?** apparaît, touchez **Autoriser** pour votre ordinateur.
- Décrivez le problème, par exemple : « La batterie baisse beaucoup pendant la nuit ». Attendez la fin.

## 3. Envoyer le résultat à votre IA

1. Choisissez **2** dans PowerShell pour ouvrir le dossier du rapport. L'option **1** affiche le rapport.
2. Joignez **ADBMedic-report.zip** à ChatGPT, Claude ou une autre IA de confiance.
3. Collez le message de départ affiché dans PowerShell. Il est aussi dans **START-PROMPT.txt**, à côté du ZIP.

L'IA doit expliquer les observations, proposer des étapes ou demander une vérification supplémentaire précise. Elle répond par défaut dans la langue de Windows ; vous pouvez en demander une autre.

**Téléphone introuvable ?** Déverrouillez-le, vérifiez l'autorisation de débogage et essayez un autre câble de données ou port USB. Si le ZIP n'a pas été créé, conservez le message d'erreur ; ne compressez pas tout le dossier vous-même.

Le rapport contient des informations privées sur le téléphone et ses applications. Le script n'envoie rien automatiquement. Partagez le ZIP uniquement avec l'IA choisie, pas sur GitHub. Vous pouvez ensuite désactiver le débogage USB. L'interface du script est en russe ou en anglais.

Gardez cette fenêtre ouverte. Si l'IA demande des mesures supplémentaires, choisissez **3** ici : sélectionnez le JSON téléchargé ou collez le JSON et terminez par **END** sur une ligne séparée. Vérifiez et confirmez les mesures, puis joignez le **nouveau ZIP à la même conversation avec l'IA**. Si la fenêtre est fermée, relancez la même commande et choisissez **Reprendre l'enquête** ; le dossier est enregistré. [Aide](../../agent/investigation-rules.md#running-a-follow-up-request-on-windows).

Si des mesures fiables existent, l'IA doit montrer un graphique utile avec heures, unités, sources et lacunes. Si les données manquent, elle doit le préciser.

<details>
<summary>Le projet est déjà téléchargé ?</summary>

Ouvrez PowerShell dans le dossier du projet et lancez :

```powershell
.\bootstrap.ps1
```

</details>

[Détails techniques et développement](../DEVELOPMENT.md) · [Licence MIT](../../LICENSE)
