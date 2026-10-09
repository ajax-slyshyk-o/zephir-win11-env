# Lists apps in apps\ and the boards each one supports or has been built for.
# Boards come from: apps\<App>\boards\*.overlay|*.conf, sample.yaml/testcase.yaml (platform_allow,
# integration_platforms), and existing build\<App>\<Board> folders.
param([string]$App = '*')
. "$PSScriptRoot\env.ps1"
$ws = $env:ZEPHYR_WS

$apps = Get-ChildItem "$ws\apps" -Directory -Filter $App -ErrorAction SilentlyContinue |
    Where-Object { Test-Path "$($_.FullName)\CMakeLists.txt" }
if (-not $apps) { Write-Host "No apps found in $ws\apps"; return }

foreach ($a in $apps) {
    $boards = @{}   # board -> list of sources
    function Add([string]$b, [string]$src) { if ($b) { if (-not $boards[$b]) { $boards[$b] = @() }; $boards[$b] += $src } }

    Get-ChildItem "$($a.FullName)\boards" -File -Include *.overlay, *.conf -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { Add $_.BaseName $_.Extension.TrimStart('.') }

    foreach ($y in 'sample.yaml', 'testcase.yaml') {
        $f = "$($a.FullName)\$y"
        if (-not (Test-Path $f)) { continue }
        # Simple parser: "platform_allow: a b" / "- a" list items under platform_allow / integration_platforms
        $key = $null
        foreach ($line in Get-Content $f) {
            if ($line -match '^\s*(platform_allow|integration_platforms)\s*:\s*(.*)$') {
                $key = $Matches[1]; $Matches[2] -split '[\s,\[\]]+' | ForEach-Object { Add $_ $y }
            } elseif ($key -and $line -match '^\s*-\s*(\S+)') { Add $Matches[1] $y }
            elseif ($line -match '^\s*\S') { $key = $null }
        }
    }

    Get-ChildItem "$ws\build\$($a.Name)" -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path "$($_.FullName)\CMakeCache.txt" } |
        ForEach-Object { Add $_.Name 'build' }

    $branch = git -C $a.FullName rev-parse --abbrev-ref HEAD 2>$null
    Write-Host "$($a.Name)" -ForegroundColor Cyan -NoNewline
    Write-Host $(if ($branch) { "  (git: $branch)" } else { '  (not a git repo)' }) -ForegroundColor DarkGray
    if (-not $boards.Count) { Write-Host '    no boards found (add boards\<board>.overlay or build it once)'; continue }
    foreach ($b in $boards.Keys | Sort-Object) {
        $elf = "$ws\build\$($a.Name)\$b\zephyr\zephyr.elf"
        $state = if (Test-Path $elf) { 'built ' + (Get-Item $elf).LastWriteTime.ToString('yyyy-MM-dd HH:mm') } else { 'not built' }
        '    {0,-28} {1,-24} [{2}]' -f $b, $state, (($boards[$b] | Select-Object -Unique) -join ', ')
    }
}
