# Builds apps\<App> for <Board> into build\<App>\<Board>
param([string]$Board, [switch]$Pristine, [string]$App)
. "$PSScriptRoot\env.ps1"
if (-not $App) { $App = $env:ZEPHIR_DEFAULT_APP }        # defaults from zephir.json
if (-not $Board) { $Board = $env:ZEPHIR_DEFAULT_BOARD }
Set-Location $env:ZEPHYR_WS
$a = @('build', '-b', $Board, "apps\$App", '-d', "build\$App\$Board", '--', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON')
if ($Pristine) { $a = @('build', '-p', 'always') + $a[1..($a.Length-1)] }
west @a
