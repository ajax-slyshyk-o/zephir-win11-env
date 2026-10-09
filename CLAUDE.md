# CLAUDE.md

Shared Zephyr development environment for Windows 11 (west workspace). Full user docs: `README.md`.
This folder is the environment only; the actual projects are separate git repos in `apps\`.

## Layout
- `apps\<name>\` - Zephyr apps, each its own git repo, **not** in any west manifest (west "workspace
  application" layout). Main app: `apps\edid-emu` (board `nucleo_l031k6`, STM32L031, 32 KB flash).
- `zephyr\` (manifest repo, `zephyr\west.yml`, v4.2.0), `modules\`, `bootloader\`, `tools\` - managed by `west update`.
  Never edit `zephyr\west.yml` for apps.
- `build\<app>\<board>\` - one build folder per app and board.
- `zephir.json` - machine settings (toolchain, programmer, extra PATH, env vars, default app/board).
  Git-ignored; template `zephir.example.json` is committed (setup.ps1 copies it if missing).
  New config keys go into both files.
- `scripts\` - `env.ps1`, `build.ps1`, `menuconfig.ps1`, `list-apps.ps1`, `setup.ps1`.
- `.vscode\` - tasks/launch/settings, hardcoded to `edid-emu` / `nucleo_l031k6`.

## Commands (PowerShell, from the workspace root)
    .\scripts\build.ps1 [-App <name>] [-Board <board>] [-Pristine]
    .\scripts\menuconfig.ps1 [-App <name>] [-Board <board>] [-Gui]
    .\scripts\list-apps.ps1 [-App <wildcard>]
    . .\scripts\env.ps1      # required before any plain `west` command (west lives only in .venv)
    west flash -d build\edid-emu\nucleo_l031k6 --runner stm32cubeprogrammer
Defaults for -App/-Board come from `zephir.json` -> `defaults`.

## Environment rules
- Run builds and west **from PowerShell** (`pwsh -NoProfile -File scripts\build.ps1` / `-Command '. .\scripts\env.ps1; west ...'`).
  **Never configure a build dir from Git Bash**: CMake caches Git's `winpty` as `PTY_INTERFACE`, and
  menuconfig then fails in pwsh with `stdin is not a tty`. Fix: `west build -d <dir> -- -UPTY_INTERFACE`.
- `D:\Projects` is a **symlink** to `E:\Projects`; the real workspace is `E:\Projects\AJAX\zephir-win11-env`.
  CMake stores `E:` paths; west run from a `D:` cwd fails with `path is on mount 'E:', start on mount 'D:'`.
  `env.ps1` (`Get-RealPath`) resolves this and `Set-Location`s to the real path - keep that logic.
  Use `E:` paths in commands.
- No hardcoded machine paths in scripts: put them in `zephir.json` (values support `%VAR%` and `${ws}`).
  Env var names use `_`, not `-`. Exception: `.vscode\launch.json` `armToolchainPath` (VS Code can't read the JSON).
- Toolchain is the user's Arm GNU GCC (`gnuarmemb`), not the Zephyr SDK.
- Python on PATH is a Store stub; use `.venv\Scripts\python.exe` for Zephyr things, or
  `C:\Users\user\anaconda3\python.exe` for helper scripts.
- `menuconfig` needs an interactive terminal: not a VS Code task (removed on purpose), and not
  runnable with redirected output. To test it, start it in a new console window.
- After moving/renaming the workspace folder: `west` fails with "uv trampoline failed to canonicalize
  script path" (venv launchers embed absolute paths). Fix: `uv pip install --python .venv\Scripts\python.exe
  --reinstall west -r zephyr\scripts\requirements.txt`, `west zephyr-export`, delete stale
  `HKCU\Software\Kitware\CMake\Packages\Zephyr` entries, and delete `build\` folders (`-Pristine` can't fix them).
- `setup.ps1` is safe to re-run (idempotent) but runs `west update`, which resets modules to manifest revisions.
  `-ZephyrRev` only applies to a fresh workspace. Don't run it without asking.

## Conventions
- Scripts: PowerShell 7, short, dot-source `env.ps1` first, then `Set-Location $env:ZEPHYR_WS`.
  Params `-App`/`-Board` with defaults filled from `$env:ZEPHIR_DEFAULT_APP` / `ZEPHIR_DEFAULT_BOARD` after loading env.
- When adding or changing a script or config key, update the matching section of `README.md`.
- Kconfig changes to keep belong in `apps\<app>\prj.conf` (menuconfig edits only `build\...\.config`, lost on `-Pristine`).
- Board devicetree: `apps\<app>\boards\<board>.overlay`.
- Editing with sed via Git Bash mangles backslashes in Windows paths; prefer exact edits.
- The workspace root is a git repo (branch `main`); `.gitignore` excludes `apps/`, `build/`, Zephyr trees,
  `.venv/`, `zephir.json`.
