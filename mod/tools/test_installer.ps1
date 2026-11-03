# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
# Runs the console installer (install.ps1) through normal and failure cases in scratch folders and
# checks what each leaves behind and what the log says. Never touches the real game, desktop or saves.
#   test_installer.ps1 -Package dist\UndertaleEssentials-<version> -DataWin <game folder>\data.win `
#       -Scratch <empty folder> [-OptionsIni <Undertale's options.ini>]
# The data.win's folder also needs UNDERTALE.exe. Exits 1 if any check fails.
# Each case gets its own copy of the game in Scratch (about 65 MB each). Prints ok/FAIL per check.
param([string]$Package, [string]$DataWin, [string]$Scratch, [string]$OptionsIni)
$ErrorActionPreference = 'Stop'
$inst = Join-Path $Package 'files\install.ps1'
$log = Join-Path ([System.IO.Path]::GetTempPath()) 'UndertaleEssentials-installer.log'
$script:fails = 0

function New-Game([string]$name, [switch]$NoDataWin) {
    $d = Join-Path $Scratch $name
    if (Test-Path $d) { Remove-Item $d -Recurse -Force }
    New-Item -ItemType Directory -Force $d, "$d\_shortcuts" | Out-Null
    Copy-Item (Join-Path (Split-Path $DataWin) 'UNDERTALE.exe') $d
    if (-not $NoDataWin) { Copy-Item $DataWin $d }
    # Undertale's own options.ini, or one in its format with the setting the installer changes
    if ($OptionsIni) { Copy-Item $OptionsIni (Join-Path $d 'options.ini') }
    else { [System.IO.File]::WriteAllText((Join-Path $d 'options.ini'), "[Windows]`r`nCreateTexturesOnDemand=0`r`nAlternateSyncMethod=1`r`nVertexBufferMethod=1`r`n") }
    return $d
}
function Run([string]$dir, [string[]]$extra = @()) {
    $before = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $inst -GameDir $dir -ShortcutDir "$dir\_shortcuts" @extra 2>&1 | Out-String
    $code = $LASTEXITCODE
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite'); $fs.Position = $before
    $newLog = (New-Object System.IO.StreamReader($fs)).ReadToEnd(); $fs.Close()
    return @{ Out = $out; Code = $code; Log = $newLog }
}
function Files([string]$dir) { (Get-ChildItem $dir -Force -File | ForEach-Object Name | Sort-Object) -join ', ' }
function Check([string]$what, [bool]$ok) {
    if (-not $ok) { $script:fails++ }
    "  $(if ($ok) { 'ok  ' } else { 'FAIL' }) $what"
}

"1. install, then uninstall"
$d = New-Game 'normal'
$optBefore = Get-Content "$d\options.ini" -Raw
$r = Run $d
Check "install exit 0 ($($r.Code))" ($r.Code -eq 0)
Check "installed: $(Files $d)" ((Files $d) -eq 'data.win, data_framerate.win, framerate_mod_installed.txt, options.ini, options.ini.framerate_mod_backup, steam_appid.txt, UNDERTALE.exe')
Check 'options.ini: AlternateSyncMethod=0' ((Get-Content "$d\options.ini" -Raw) -match '(?m)^AlternateSyncMethod=0')
Check 'shortcut made' (Test-Path "$d\_shortcuts\Undertale Essentials.lnk")
Check 'log has the run header, Windows and data.win SHA-1' ($r.Log -match '===== Undertale Essentials .* - install =====' -and $r.Log -match 'Windows:' -and $r.Log -match 'SHA-1 cb394cdd')
$r = Run $d @('-Uninstall')
Check "uninstall exit 0 ($($r.Code))" ($r.Code -eq 0)
Check "after uninstall: $(Files $d)" ((Files $d) -eq 'data.win, options.ini, UNDERTALE.exe')
Check 'options.ini back to the original' ((Get-Content "$d\options.ini" -Raw) -eq $optBefore)
Check 'shortcut removed' (-not (Test-Path "$d\_shortcuts\Undertale Essentials.lnk"))

"2. reinstall over an install"
$d = New-Game 'reinstall'
$r1 = Run $d; $r2 = Run $d
Check "both exit 0 ($($r1.Code), $($r2.Code))" ($r1.Code -eq 0 -and $r2.Code -eq 0)
Check "record: $((Get-Content "$d\framerate_mod_installed.txt") -join ' | ')" (@(Get-Content "$d\framerate_mod_installed.txt").Count -eq 3)
$r = Run $d @('-Uninstall')
Check "uninstall leaves $(Files $d)" ((Files $d) -eq 'data.win, options.ini, UNDERTALE.exe')

"3. wrong data.win: already modded, another version, missing"
# "modded": this package's own data_framerate.win, copied over data.win by hand
$src = New-Game 'modded-source'
$null = Run $src
$d = New-Game 'modded'
Copy-Item "$src\data_framerate.win" "$d\data.win" -Force
Remove-Item $src -Recurse -Force
$r = Run $d
Check "modded: exit 1, says already modded, nothing added ($(Files $d))" ($r.Code -eq 1 -and $r.Out -match 'already been replaced' -and (Files $d) -eq 'data.win, options.ini, UNDERTALE.exe')
$d = New-Game 'other'
$fs = [System.IO.File]::Open("$d\data.win", 'Open'); $fs.SetLength(1000000); $fs.Close()
$r = Run $d
Check "other version: exit 1, says not v1.08, says how to verify" ($r.Code -eq 1 -and $r.Out -match "isn't the one from Undertale v1.08" -and $r.Out -match 'Verify integrity')
$d = New-Game 'missing' -NoDataWin
$r = Run $d
Check "missing: exit 1, says there's no data.win" ($r.Code -eq 1 -and $r.Out -match "There's no data.win")

"4. Undertale running from the folder"
$d = New-Game 'running'
Copy-Item "$env:SystemRoot\System32\PING.EXE" "$d\UNDERTALE.exe" -Force
$p = Start-Process "$d\UNDERTALE.exe" -ArgumentList '-n', '60', '127.0.0.1' -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 500
$r = Run $d
Stop-Process -Id $p.Id -Force; Start-Sleep -Milliseconds 300
Check "exit 1, says close the game, nothing added ($(Files $d))" ($r.Code -eq 1 -and $r.Out -match 'Close the game first' -and (Files $d) -eq 'data.win, options.ini, UNDERTALE.exe')

"5. install fails part-way (data_framerate.win locked): everything undone"
$d = New-Game 'locked'
Set-Content "$d\data_framerate.win" 'old'
$optBefore = Get-Content "$d\options.ini" -Raw
$lock = [System.IO.File]::Open("$d\data_framerate.win", 'Open', 'ReadWrite', 'None')
$r = Run $d
$lock.Close()
Check "exit 1, says it was undone" ($r.Code -eq 1 -and $r.Out -match 'were undone')
Check "folder as before: $(Files $d)" ((Files $d) -eq 'data.win, data_framerate.win, options.ini, UNDERTALE.exe')
Check 'options.ini unchanged' ((Get-Content "$d\options.ini" -Raw) -eq $optBefore)
Check 'log says where it failed, with the script line' ($r.Log -match 'failed while putting data_framerate.win in place' -and $r.Log -match 'at .*install\.ps1')

"6. uninstall with a file in use, then again"
$d = New-Game 'uninstall_locked'
$r = Run $d
$lock = [System.IO.File]::Open("$d\data_framerate.win", 'Open', 'Read', 'None')
$r = Run $d @('-Uninstall')
$lock.Close()
Check "exit 1, names the file, keeps it in the record" ($r.Code -eq 1 -and $r.Out -match "Couldn't remove data_framerate.win" -and ((Get-Content "$d\framerate_mod_installed.txt") -join '|') -eq 'data_framerate.win')
Check 'the rest was removed (shortcut, steam_appid.txt, options backup)' (-not (Test-Path "$d\_shortcuts\Undertale Essentials.lnk") -and -not (Test-Path "$d\steam_appid.txt") -and -not (Test-Path "$d\options.ini.framerate_mod_backup"))
$r = Run $d @('-Uninstall')
Check "second uninstall exit 0, leaves $(Files $d)" ($r.Code -eq 0 -and (Files $d) -eq 'data.win, options.ini, UNDERTALE.exe')

"7. no desktop folder for the shortcut: installs anyway, with a warning"
$d = New-Game 'noshortcut'
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $inst -GameDir $d -ShortcutDir "$d\no such folder" 2>&1 | Out-String
$code = $LASTEXITCODE
Check "exit 0, warns about the shortcut" ($code -eq 0 -and $out -match "Couldn't make the desktop shortcut")
Check "record has no shortcut: $((Get-Content "$d\framerate_mod_installed.txt") -join ' | ')" (-not ((Get-Content "$d\framerate_mod_installed.txt") -match 'shortcut='))
$r = Run $d @('-Uninstall')
Check "uninstall exit 0, leaves $(Files $d)" ($r.Code -eq 0 -and (Files $d) -eq 'data.win, options.ini, UNDERTALE.exe')

"8. installer without its patch file"
$lone = Join-Path $Scratch 'lone_installer'
New-Item -ItemType Directory -Force $lone | Out-Null
Copy-Item $inst $lone
$d = New-Game 'nopatch'
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File "$lone\install.ps1" -GameDir $d -ShortcutDir "$d\_shortcuts" 2>&1 | Out-String
Check "exit 1, says unzip first ($LASTEXITCODE)" ($LASTEXITCODE -eq 1 -and $out -match 'Unzip the whole folder first')

''
if ($script:fails -eq 0) { 'all checks passed' } else { "$($script:fails) check(s) failed"; exit 1 }
