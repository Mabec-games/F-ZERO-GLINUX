# Package the Windows JIT build as a portable zip, the counterpart of
# package-appimage.sh. No game images, extracted games, modules or saves.
#
#   powershell -ExecutionPolicy Bypass -File scripts\package-windows.ps1 [-Version preview-20261025]
param([string]$Version = "preview-$(Get-Date -Format yyyyMMdd)")
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = "$root\lib\ModernGekko\build"
foreach ($exe in 'ModernGekko.exe', 'moderngekko-run.exe') {
    if (-not (Test-Path "$build\$exe")) { throw "Build first: scripts\build-windows.ps1 ($exe missing)" }
}

$name = "F-ZERO-GLINUX-$Version-windows-x64"
$stage = "$root\build\windows-package\$name"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage\Assets", "$stage\licenses" | Out-Null

Copy-Item "$build\ModernGekko.exe" "$stage\F-ZERO GLINUX.exe"
# The launcher starts the runner and the quit dialog by these names.
Copy-Item "$build\ModernGekko.exe", "$build\moderngekko-run.exe" $stage
Copy-Item -Recurse "$build\Sys" "$stage\Sys"
Copy-Item "$root\assets\launcher\*.png", "$root\assets\fonts\NotoSans-*.ttf" "$stage\Assets\"
Copy-Item "$root\lib\ModernGekko\LICENSE" "$stage\licenses\ModernGekko.txt"
Copy-Item "$root\lib\ModernGekko\vendor\dolphin\COPYING" "$stage\licenses\Dolphin.txt"
Copy-Item "$root\assets\fonts\OFL.txt" "$stage\licenses\NotoSans.txt"

# App-local Visual C++ runtime, so players do not need the redistributable installed.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT" -Directory |
    Sort-Object FullName | Select-Object -Last 1
if (-not $crt) { throw 'Visual C++ redistributable DLLs were not found.' }
foreach ($dll in 'msvcp140.dll', 'msvcp140_atomic_wait.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item "$($crt.FullName)\$dll" $stage
}

@"
F-ZERO GLINUX $Version for Windows (x64)

1. Run "F-ZERO GLINUX.exe".
2. Click "Browse for ISO / RVZ" and pick your own F-Zero GX (USA, GFZE01) disc image.
   It is extracted once into a "GFZE01" folder right next to your ISO/RVZ; the original file is not changed.
3. Pick your controller under CONTROLLER, then PLAY.

Escape (or Guide / Start+Back on a gamepad) asks before quitting.
Saves and settings live in %LOCALAPPDATA%\fzero-glinux.
The first start compiles shaders, which can take a few minutes on slower GPUs.

This is a Dolphin JIT build, not a static recompilation. No game data is included.
Licences: see the licenses folder. The Visual C++ runtime DLLs are Microsoft
redistributables, included so no separate installer is needed.
"@ | Set-Content -Encoding utf8 "$stage\README.txt"

New-Item -ItemType Directory -Force "$root\dist" | Out-Null
$zip = "$root\dist\$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip
$hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
# LF only: with CRLF, `sha256sum -c` on Linux looks for a file name ending in \r.
[IO.File]::WriteAllText("$zip.sha256", "$hash  $name.zip`n")
Write-Host "Package: $zip"
Write-Host "SHA-256: $hash"
