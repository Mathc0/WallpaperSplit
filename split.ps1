# Découpe l'image "span" de Wallpaper Engine en une image par écran
# et l'applique par moniteur (Remplir) via IDesktopWallpaper.
param([switch]$Watch)
$ErrorActionPreference = 'Stop'
$dir   = Join-Path $env:LOCALAPPDATA 'WallpaperSplit'
$theme = Join-Path $env:APPDATA 'Microsoft\Windows\Themes'
Add-Type -AssemblyName System.Drawing
if (-not ('WPS.Native' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
namespace WPS {
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDesktopWallpaper {
  void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
  [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
  [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt(uint monitorIndex);
  uint GetMonitorDevicePathCount();
  RECT GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
  void SetBackgroundColor(uint color); uint GetBackgroundColor();
  void SetPosition(int position); int GetPosition();
}
[ComImport, Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")] public class DesktopWallpaperClass {}
public static class Native {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  static IDesktopWallpaper W() { return (IDesktopWallpaper)new DesktopWallpaperClass(); }
  public static uint Count() { return W().GetMonitorDevicePathCount(); }
  public static string PathAt(uint i) { return W().GetMonitorDevicePathAt(i); }
  public static RECT Rect(string id) { return W().GetMonitorRECT(id); }
  public static void SetPos(int p) { W().SetPosition(p); }
  public static void Set(string id, string path) { W().SetWallpaper(id, path); }
}}
'@
}
[WPS.Native]::SetProcessDpiAwarenessContext([IntPtr]-4) | Out-Null

function Invoke-Split {
  $src = Get-ChildItem $theme -Filter 'WallpaperEngineOverride*.jpg' | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if (-not $src) { return }

  $n = [WPS.Native]::Count()
  $mons = for ($i = 0; $i -lt $n; $i++) {
    $id = [WPS.Native]::PathAt($i)
    try { [pscustomobject]@{ Id = $id; R = [WPS.Native]::Rect($id) } } catch {}
  }
  $mons = @($mons | Where-Object { $_.R.Right -gt $_.R.Left })
  if ($mons.Count -lt 2) { return }
  $minX = ($mons | % { $_.R.Left }   | Measure -Min).Minimum
  $minY = ($mons | % { $_.R.Top }    | Measure -Min).Minimum
  $maxX = ($mons | % { $_.R.Right }  | Measure -Max).Maximum
  $maxY = ($mons | % { $_.R.Bottom } | Measure -Max).Maximum
  # Copie en mémoire pour ne pas verrouiller le fichier de Wallpaper Engine
  $bytes = [IO.File]::ReadAllBytes($src.FullName)
  $ms = New-Object IO.MemoryStream(,$bytes)
  $img = [System.Drawing.Image]::FromStream($ms)
  $sx = $img.Width / ($maxX - $minX); $sy = $img.Height / ($maxY - $minY)
  $stamp = Get-Date -Format 'yyyyMMddHHmmss'
  Get-ChildItem $dir -Filter 'mon*.jpg' -ea 0 | Remove-Item -Force -ea 0
  $k = 0
  foreach ($m in $mons) {
    $w = $m.R.Right - $m.R.Left; $h = $m.R.Bottom - $m.R.Top
    $srcRect = New-Object System.Drawing.RectangleF((($m.R.Left - $minX) * $sx), (($m.R.Top - $minY) * $sy), ($w * $sx), ($h * $sy))
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF(0, 0, $w, $h)), $srcRect, 'Pixel')
    $out = Join-Path $dir ("mon{0}_{1}.jpg" -f $k, $stamp)
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | ? MimeType -eq 'image/jpeg'
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]95)
    $bmp.Save($out, $codec, $ep)
    $g.Dispose(); $bmp.Dispose()
    $m | Add-Member Out $out; $k++
  }
  $img.Dispose(); $ms.Dispose()
  [WPS.Native]::SetPos(4)   # DWPOS_FILL (au lieu de SPAN)
  foreach ($m in $mons) { [WPS.Native]::Set($m.Id, $m.Out) }
}

Invoke-Split
if ($Watch) {
  $fsw = New-Object IO.FileSystemWatcher($theme, 'WallpaperEngineOverride*.jpg')
  $fsw.NotifyFilter = 'LastWrite, FileName, Size'
  while ($true) {
    $r = $fsw.WaitForChanged('Changed, Created, Renamed', 60000)
    if ($r.TimedOut) {
      # Filet de sécurité : si WE a remis le mode Span, on ré-applique
      if ((Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallpaperStyle -eq '22') { try { Invoke-Split } catch {} }
      continue
    }
    Start-Sleep -Milliseconds 1500   # laisser WE finir d'écrire
    try { Invoke-Split } catch {}
  }
}
