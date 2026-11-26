# Installe la tâche planifiée qui lance split.ps1 -Watch à chaque ouverture de session.
$ErrorActionPreference = 'Stop'
$target = Join-Path $env:LOCALAPPDATA 'WallpaperSplit'
New-Item -ItemType Directory -Force $target | Out-Null
if ((Resolve-Path $PSScriptRoot).Path -ne (Resolve-Path $target).Path) {
  Copy-Item (Join-Path $PSScriptRoot 'split.ps1') $target -Force
}
$s = Join-Path $target 'split.ps1'
$user = "$env:USERDOMAIN\$env:USERNAME"
$a = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$s`" -Watch"
$t = New-ScheduledTaskTrigger -AtLogOn -User $user
$t.Delay = 'PT20S'
$st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
$p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'WallpaperSplit' -Action $a -Trigger $t -Settings $st -Principal $p -Description 'Découpe le fond Wallpaper Engine par écran (aperçu/Mica)' -Force | Out-Null
Start-ScheduledTask -TaskName 'WallpaperSplit'
Write-Host 'Tâche WallpaperSplit installée et démarrée.'