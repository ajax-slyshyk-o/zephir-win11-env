# Zephyr + VS Code on Windows 11 (shared environment for Zephyr apps)

This folder is a west workspace: one Zephyr tree, toolchain setup and Python venv shared by
several apps. Each app lives in `apps/` as its own git repo and is **not** listed in `west.yml`.

    zephir/
      apps/edid-emu/                   app (own git repo)
      apps/<other>/                    more apps, same way
      zephyr/ modules/ bootloader/ tools/   Zephyr + modules, created by `west update`
      .venv/                           Python env (uv) with west
      .west/                           west workspace config (manifest = zephyr/west.yml)
      zephir.json                      machine settings: toolchain, programmer, PATH, env vars (git-ignored)
      zephir.example.json              template for zephir.json (committed)
      scripts/  .vscode/               environment scripts and VS Code config
      build/<app>/<board>/             build output, one folder per app and board

## Prerequisites
PowerShell 7 (`pwsh`), cmake, ninja, git, uv, an Arm GNU toolchain, STM32CubeProgrammer (flashing).
Optional: OpenOCD (`winget install openocd`, only for F5 debugging).
VS Code extensions are suggested on first open (`.vscode/extensions.json`): C/C++, Cortex-Debug,
CMake Tools, nRF DeviceTree.

Set the toolchain and programmer locations for your machine in `zephir.json` (see
[Configuration](#configuration)). Nothing is added to the global PATH; `env.ps1` sets everything
per terminal.

## Configuration
`zephir.json` in the workspace root holds all machine-specific settings. `env.ps1` reads it, so
changes apply to every new terminal and every script run (in an open terminal: `. .\scripts\env.ps1`).

`zephir.json` is personal and git-ignored. The committed template is `zephir.example.json`;
`setup.ps1` copies it to `zephir.json` if that doesn't exist (or copy it by hand), then edit the paths.
When you add a new key, add it to `zephir.example.json` too.

    {
        "toolchain": {
            "variant": "gnuarmemb",
            "path": "D:\\bin\\_compilers\\_latests\\gcc-arm-none-eabi"
        },
        "programmer": "C:\\Program Files\\STMicroelectronics\\STM32Cube\\STM32CubeProgrammer\\bin",
        "paths": [],
        "env": { "ZEPHIR_WIN11": "1" },
        "defaults": { "app": "edid-emu", "board": "nucleo_l031k6" }
    }

| Key | Meaning |
|---|---|
| `toolchain.variant` | `gnuarmemb` (your own Arm GCC) or `zephyr` (Zephyr SDK). Sets `ZEPHYR_TOOLCHAIN_VARIANT`. |
| `toolchain.path` | `gnuarmemb`: GCC root folder (the one containing `bin\`), sets `GNUARMEMB_TOOLCHAIN_PATH` and adds `bin\` to PATH. `zephyr`: SDK folder, sets `ZEPHYR_SDK_INSTALL_DIR` (optional). |
| `programmer` | STM32CubeProgrammer `bin` folder, added to PATH (needed by `west flash`). |
| `paths` | Extra folders to add to PATH, e.g. `["C:\\tools\\openocd\\bin"]`. Folders that don't exist are skipped. |
| `env` | Extra environment variables as `"NAME": "value"`, e.g. `"ZEPHIR_WIN11": "1"` (example, not used by anything) or `"ZEPHYR_SDK_INSTALL_DIR": "D:\\zephyr-sdk"`. Values are strings; use `_`, not `-`, in names. |
| `defaults.app`, `defaults.board` | What `build.ps1` and `menuconfig.ps1` use when `-App`/`-Board` aren't given. |

- In JSON, backslashes in paths must be doubled (`"D:\\bin"`); forward slashes (`"D:/bin"`) work too.
- Values may use `%VAR%` (Windows environment variables, e.g. `%USERPROFILE%`) and `${ws}`
  (the workspace path, e.g. `"${ws}\\tools\\bin"`).
- A wrong `toolchain.path` or `programmer` prints a warning when the environment loads.
- Not covered by the config: `.vscode/launch.json` (`armToolchainPath` for debugging) still has
  the GCC path written in it; change it there too if you move the toolchain.

## One-time setup
    pwsh scripts\setup.ps1            # Zephyr v4.2.0; or: -ZephyrRev main
Creates `.venv` with uv, installs west, runs `west init/update` (several GB), installs Zephyr's
Python requirements, and installs dtc and gperf via winget (Zephyr SDK 0.17 has no Windows host tools).
If git complains about long paths: `git config --system core.longpaths true`.

## Daily use
Run everything from the workspace folder in PowerShell. The `scripts\*.ps1` load the environment
themselves; for plain `west` commands load it once per terminal with `. .\scripts\env.ps1`
(the VS Code terminal profile **Zephyr** does this automatically).

Scripts: see [Scripts](#scripts) below. Most used:

    .\scripts\build.ps1
    .\scripts\menuconfig.ps1

Plain west, for edid-emu (`west` is only in the venv, so load the env first in a new terminal,
otherwise you get "west: The term 'west' is not recognized"):

    . .\scripts\env.ps1                                          # once per terminal
    west build -b nucleo_l031k6 apps\edid-emu -d build\edid-emu\nucleo_l031k6
    west build -d build\edid-emu\nucleo_l031k6                   # rebuild an existing build dir
    west build -t menuconfig -d build\edid-emu\nucleo_l031k6
    west flash -d build\edid-emu\nucleo_l031k6 --runner stm32cubeprogrammer

VS Code (set up for edid-emu on nucleo_l031k6):
- Ctrl+Shift+B -> `Zephyr: build` (output `build/edid-emu/nucleo_l031k6`); `Zephyr: build pristine`
- Task `Zephyr: flash` (west + STM32CubeProgrammer over ST-LINK)
- F5 -> Cortex-Debug with OpenOCD
- IntelliSense uses `build/edid-emu/nucleo_l031k6/compile_commands.json` (exists after the first build)

menuconfig changes only go to `build\...\zephyr\.config` and are lost on a pristine build.
Copy the `CONFIG_...` lines you want to keep into the app's `prj.conf`.

## Scripts
All scripts live in `scripts\` and can be run from any folder. `-App` is a folder name in
`apps\`; `-Board` is a Zephyr board name. Defaults come from `defaults` in `zephir.json`
(currently `-App edid-emu`, `-Board nucleo_l031k6`).

### env.ps1: load the environment
    . .\scripts\env.ps1
Must be **dot-sourced** (`. ` in front), otherwise the settings are dropped when it ends.
Reads `zephir.json`, puts the venv (`west`), the toolchain, the programmer and your extra `paths`
on PATH for this terminal, and sets `ZEPHYR_BASE`, `ZEPHYR_TOOLCHAIN_VARIANT`,
`GNUARMEMB_TOOLCHAIN_PATH`, `ZEPHYR_WS` and your extra `env` variables.
Moves a terminal opened through the `D:\` symlink to the real `E:\` path. Safe to run repeatedly.
The other scripts and the VS Code **Zephyr** terminal call it automatically.

### build.ps1: build an app
    .\scripts\build.ps1 [-App <name>] [-Board <board>] [-Pristine]
Builds `apps\<App>` for `<Board>` into `build\<App>\<Board>` and writes `compile_commands.json`
for IntelliSense. Only changed files are rebuilt.
- `-Pristine`: delete the build folder contents and rebuild from scratch (`west build -p always`).
  Use after changing board, toolchain, Zephyr version or CMake files, or on strange build errors.
  This also drops menuconfig changes.

Examples:

    .\scripts\build.ps1                                   # edid-emu, nucleo_l031k6
    .\scripts\build.ps1 -Pristine                         # clean rebuild
    .\scripts\build.ps1 -App other-proj -Board nucleo_f411re

### menuconfig.ps1: edit Kconfig interactively
    .\scripts\menuconfig.ps1 [-App <name>] [-Board <board>] [-Gui]
Opens menuconfig for `build\<App>\<Board>`. If that folder isn't built yet, it runs `build.ps1` first.
Run it in a real terminal (Windows Terminal or the VS Code terminal), not as a VS Code task.
- `-Gui`: open the guiconfig window instead of the text UI.

Changes are saved to `build\<App>\<Board>\zephyr\.config` only; copy lines you want to keep into
`apps\<App>\prj.conf`.

### list-apps.ps1: list apps and their boards
    .\scripts\list-apps.ps1 [-App <name|wildcard>]
Prints every app in `apps\` (folders with a `CMakeLists.txt`), its git branch, and its boards.
Boards are collected from `boards\*.overlay` / `boards\*.conf`, `platform_allow` and
`integration_platforms` in `sample.yaml` / `testcase.yaml`, and existing `build\<App>\<Board>` folders.
Each board shows whether `zephyr.elf` is built (and when) and where the board was found:

    edid-emu  (git: master)
        nucleo_l031k6                built 2026-10-09 12:43   [overlay, build]

Note: an app can also build for boards it has no files for; this lists only boards the app mentions.

### setup.ps1: one-time workspace setup
    pwsh scripts\setup.ps1 [-ZephyrRev <tag|branch>]
Creates `zephir.json` from `zephir.example.json` if missing, `apps\` and `.venv` (uv, Python 3.12) and installs west; runs `west init` if `.west\` doesn't exist,
then `west update` and `west zephyr-export`; installs Zephyr's Python requirements; installs dtc and
gperf via winget. Can be re-run to update modules and requirements.
- `-ZephyrRev`: Zephyr version for a new workspace (default `v4.2.0`, or `main`). Only used when
  `zephyr\` doesn't exist yet; it doesn't change an existing checkout.

## Adding an app
    git clone <url> apps\<name>
    .\scripts\build.ps1 -App <name> -Board <board>
    west flash -d build\<name>\<board> --runner stm32cubeprogrammer
The VS Code tasks, debug config and IntelliSense paths are hardcoded to `edid-emu`/`nucleo_l031k6`.
To work on another app in VS Code, change `edid-emu` and the board name in `.vscode/settings.json`,
`tasks.json` and `launch.json`.

## Notes
- `D:\Projects` is a symlink to `E:\Projects`. CMake stores the real `E:` paths, so west fails with
  `path is on mount 'E:', start on mount 'D:'` if run from the `D:` path. `env.ps1` handles this by
  switching the terminal to the real path; in an old terminal just run `. .\scripts\env.ps1` again.
- Don't configure a build from Git Bash: Zephyr then picks up Git's `winpty`, and menuconfig fails
  in PowerShell with `stdin is not a tty`. Fix: `west build -d <build dir> -- -UPTY_INTERFACE`.
- Board-specific devicetree goes in the app's `boards/<board>.overlay`
  (edid-emu has `boards/nucleo_l031k6.overlay`).
- Arm GNU 15.x is newer than what Zephyr is tested with. If builds break, try the toolchain
  version the Zephyr docs list, or `west sdk install -t arm-zephyr-eabi` and set variant `zephyr`.
