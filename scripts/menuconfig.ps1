# Interactive Kconfig for apps\<App> (run from a terminal, not a VS Code task). -Gui for guiconfig
param([string]$Board, [string]$App, [switch]$Gui)
. "$PSScriptRoot\env.ps1"
if (-not $App) { $App = $env:ZEPHIR_DEFAULT_APP }        # defaults from zephir.json
if (-not $Board) { $Board = $env:ZEPHIR_DEFAULT_BOARD }
Set-Location $env:ZEPHYR_WS
$d = "build\$App\$Board"
if (-not (Test-Path "$d\build.ninja")) { & "$PSScriptRoot\build.ps1" -Board $Board -App $App }
west build -t $(if ($Gui) { 'guiconfig' } else { 'menuconfig' }) -d $d
