# Dot-source:  . .\scripts\env.ps1   (idempotent; also used by VS Code terminal profile and tasks)
# Resolve symlinked parents (D:\Projects -> E:\Projects): CMake caches real paths and west fails
# with "path is on mount 'E:', start on mount 'D:'" when the cwd uses the link path.
function Get-RealPath([string]$Path) {
    $full = (Resolve-Path -LiteralPath $Path).Path
    for ($cur = $full; $cur; $cur = Split-Path $cur -Parent) {
        $item = Get-Item -LiteralPath $cur -Force
        if ($item.LinkTarget) {
            return Get-RealPath (Join-Path $item.ResolveLinkTarget($true).FullName $full.Substring($cur.Length))
        }
    }
    $full
}
$ws = Get-RealPath "$PSScriptRoot\.."
$env:ZEPHYR_WS = "$ws"
# Move a terminal opened via the link path to the same place under the real path
$here = Get-RealPath $PWD.Path
if ($here -ne $PWD.Path -and $here.StartsWith($ws, [StringComparison]::OrdinalIgnoreCase)) { Set-Location $here }
# Machine-specific settings come from zephir.json in the workspace root (see README "Configuration").
# Values may use %VAR% (Windows env vars) and ${ws} (workspace path).
$cfgFile = "$ws\zephir.json"
$cfg = if (Test-Path $cfgFile) { Get-Content -Raw $cfgFile | ConvertFrom-Json } else { Write-Warning "$cfgFile not found, using defaults (copy zephir.example.json to zephir.json and edit it)"; [pscustomobject]@{} }
function Expand([string]$s) { if ($s) { [Environment]::ExpandEnvironmentVariables($s.Replace('${ws}', $ws)) } }
$env:ZEPHIR_DEFAULT_APP = if ($cfg.defaults.app) { $cfg.defaults.app } else { 'edid-emu' }
$env:ZEPHIR_DEFAULT_BOARD = if ($cfg.defaults.board) { $cfg.defaults.board } else { 'nucleo_l031k6' }

# Toolchain: gnuarmemb = your own Arm GCC (path = its root folder); zephyr = Zephyr SDK (path = SDK dir, optional)
$variant = if ($cfg.toolchain.variant) { $cfg.toolchain.variant } else { 'gnuarmemb' }
$tc = Expand $cfg.toolchain.path
$env:ZEPHYR_TOOLCHAIN_VARIANT = $variant
$extra = @("$ws\.venv\Scripts")   # Python venv (created by uv) -> west
switch ($variant) {
    'gnuarmemb' { $env:GNUARMEMB_TOOLCHAIN_PATH = $tc; $extra += "$tc\bin" }
    'zephyr'    { if ($tc) { $env:ZEPHYR_SDK_INSTALL_DIR = $tc } }
}
if ($tc -and -not (Test-Path $tc)) { Write-Warning "toolchain.path not found: $tc (edit $cfgFile)" }
$prog = Expand $cfg.programmer
if ($prog) { if (Test-Path $prog) { $extra += $prog } else { Write-Warning "programmer not found: $prog (edit $cfgFile)" } }
foreach ($p in $cfg.paths) { $extra += Expand $p }
if ($cfg.env) { foreach ($kv in $cfg.env.PSObject.Properties) { Set-Item "env:$($kv.Name)" (Expand "$($kv.Value)") } }
# dtc/gperf come from winget (see setup.ps1); refresh PATH so a fresh install is visible
$env:PATH += ';' + [Environment]::GetEnvironmentVariable('PATH','User') + ';' + [Environment]::GetEnvironmentVariable('PATH','Machine')
foreach ($p in $extra) { if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) { $env:PATH = "$p;$env:PATH" } }

# Hide global/system python confusion; west reads the ws from .west/
$env:VIRTUAL_ENV = "$ws\.venv"
$env:ZEPHYR_BASE = "$ws\zephyr"
