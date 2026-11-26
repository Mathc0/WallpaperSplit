# Supprime la tâche planifiée et les images générées.
Stop-ScheduledTask -TaskName 'WallpaperSplit' -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'WallpaperSplit' -Confirm:$false -ErrorAction SilentlyContinue
Get-ChildItem (Join-Path $env:LOCALAPPDATA 'WallpaperSplit') -Filter 'mon*.jpg' -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Host 'Tâche WallpaperSplit supprimée.'