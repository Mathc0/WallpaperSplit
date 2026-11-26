# WallpaperSplit

Corrige l'aperçu du fond d'écran dans **Paramètres Windows 11** (et l'effet **Mica**) quand on utilise **Wallpaper Engine** avec plusieurs écrans.

## Le problème

Pour que Mica suive le fond animé, Wallpaper Engine définit aussi le fond Windows. Avec plusieurs écrans, il génère **une seule image couvrant tout le bureau virtuel** en mode *Étendre* (`WallpaperStyle = 22`).
Si les écrans n'ont pas la même résolution ou le même alignement, cette image contient des **zones noires** là où il n'y a aucun écran, et l'aperçu de Paramètres → Accueil / Personnalisation affiche ce rectangle noir.

## La solution

`split.ps1` :

1. lit l'image `WallpaperEngineOverride*.jpg` générée par Wallpaper Engine (`%APPDATA%\Microsoft\Windows\Themes`) ;
2. la découpe selon la position réelle de chaque écran (coordonnées physiques, DPI-aware) ;
3. applique une image **par moniteur** en mode *Remplir* via l'API COM `IDesktopWallpaper`.

Avec `-Watch`, il reste en arrière-plan, surveille le fichier de Wallpaper Engine et réapplique la découpe à chaque changement de fond (avec une vérification toutes les 60 s si le mode *Étendre* est revenu).

## Installation

```powershell
git clone https://github.com/Mathc0/WallpaperSplit.git
cd WallpaperSplit
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Le script est copié dans `%LOCALAPPDATA%\WallpaperSplit` et une tâche planifiée `WallpaperSplit` le lance (sans fenêtre) à chaque ouverture de session.

Lancement ponctuel, sans tâche :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\split.ps1
```

## Désinstallation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

## Prérequis

- Windows 10/11, Windows PowerShell 5.1
- Wallpaper Engine avec l'option qui définit le fond d'écran Windows (pour Mica)
- Au moins 2 écrans (avec un seul écran le script ne fait rien)