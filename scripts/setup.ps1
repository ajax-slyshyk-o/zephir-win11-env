# One-time setup: venv + west + Zephyr sources + python deps (+ host tools)
param([string]$ZephyrRev = 'v4.2.0')   # use 'main' for latest
$ErrorActionPreference = 'Stop'
# Machine settings (git-ignored): create from the template on first run, then edit paths
if (-not (Test-Path "$PSScriptRoot\..\zephir.json")) {
    Copy-Item "$PSScriptRoot\..\zephir.example.json" "$PSScriptRoot\..\zephir.json"
    Write-Warning "Created zephir.json from zephir.example.json - check toolchain/programmer paths in it."
}
. "$PSScriptRoot\env.ps1"   # resolves the real (non-symlink) workspace path
$ws = $env:ZEPHYR_WS
Set-Location $ws
New-Item -ItemType Directory -Force apps | Out-Null   # your apps go here: git clone <url> apps\<name>

if (-not (Test-Path .venv)) { uv venv .venv --python 3.12 }
uv pip install --python .venv\Scripts\python.exe west
. "$PSScriptRoot\env.ps1"

function Check { if ($LASTEXITCODE -ne 0) { throw "failed (exit $LASTEXITCODE)" } }
if (-not (Test-Path .west\config)) {
    if (Test-Path zephyr\west.yml) { west init -l zephyr } else { west init -m https://github.com/zephyrproject-rtos/zephyr --mr $ZephyrRev $ws }
    Check
}
west update --narrow -o=--depth=1; Check      # fetches zephyr + modules (several GB, takes a while)
west zephyr-export; Check
uv pip install --python .venv\Scripts\python.exe -r zephyr\scripts\requirements.txt

# dtc / gperf (SDK 0.17 has no Windows host tools)
foreach ($id in 'oss-winget.dtc', 'oss-winget.gperf') { winget install -e --id $id --accept-source-agreements --accept-package-agreements }
# openocd (only for the Cortex-Debug launch config; flashing uses STM32CubeProgrammer): winget install openocd

Write-Host "`nDone. Clone apps into apps\<name>, then: .\scripts\build.ps1 -App <name>"
