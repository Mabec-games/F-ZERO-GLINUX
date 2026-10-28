# Build the Dolphin-derived runtime and launcher with MSVC, the Windows
# counterpart of build-glinux.sh. Needs Visual Studio 2022 (Build Tools) with
# "Desktop development with C++", CMake and Ninja.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
param([int]$Jobs = [Environment]::ProcessorCount)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Apply-Patch([string]$source, [string]$patch) {
    # A failed --check is expected (patch already applied); Windows PowerShell
    # would otherwise turn git's stderr into a terminating error.
    $ErrorActionPreference = 'Continue'
    git -C $source apply --check $patch 2>$null
    if ($LASTEXITCODE -eq 0) {
        git -C $source apply $patch
        if ($LASTEXITCODE -ne 0) { throw "Applying $patch failed." }
        return
    }
    git -C $source apply --reverse --check $patch 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Patch $patch conflicts with this checkout; existing changes were preserved."
    }
}
Apply-Patch "$root\lib\ModernGekko\vendor\dolphin" "$root\patches\dolphin-glinux-performance.patch"
Apply-Patch "$root\lib\ModernGekko" "$root\patches\moderngekko-glinux-launcher.patch"

# Import the MSVC environment (cl, link, Windows SDK) unless it is already set.
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'Visual Studio with the C++ x64 tools was not found.' }
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
    }
}

$build = "$root\lib\ModernGekko\build"
$extra = @(if ($env:GLINUX_CMAKE_ARGS) { $env:GLINUX_CMAKE_ARGS -split ' ' })
cmake -S lib/ModernGekko -B $build -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DBUILD_TESTING=OFF `
    -DDOLRECOMP_ENABLE_LLVM=OFF `
    "-DMODERNGEKKO_FRONTEND_NAME=F-ZERO GLINUX" `
    "-DMODERNGEKKO_DEFAULT_WINDOW_TITLE=F-ZERO GLINUX" `
    -DMODERNGEKKO_USER_DIRECTORY_NAME=fzero-glinux `
    -DMODERNGEKKO_GAMECUBE_CONTROLLERS=ON `
    -DMODERNGEKKO_REQUIRED_DISC_ID=GFZE01 `
    -DMODERNGEKKO_DEFAULT_JIT=ON `
    "-DMODERNGEKKO_WINDOWS_ICON=$root\packaging\windows\fzero-glinux.ico" `
    @extra
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
cmake --build $build --target moderngekko-launcher moderngekko-run -j $Jobs
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

New-Item -ItemType Directory -Force "$build\Assets" | Out-Null
Copy-Item "$root\assets\launcher\*.png", "$root\assets\fonts\NotoSans-*.ttf" "$build\Assets\"
Write-Host "Built: $build\ModernGekko.exe"
