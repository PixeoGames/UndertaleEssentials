# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
# Undertale Essentials - installer / uninstaller.
# Builds data_framerate.win from the player's own data.win using data_framerate.patch, and adds a
# desktop shortcut that starts it. The only Undertale file it changes is options.ini (one setting,
# with a backup that uninstalling puts back): GameMaker's AlternateSyncMethod=1 locks every frame to
# the monitor's refresh, which caps the mod at the refresh rate and makes lower caps uneven.
#   install.ps1 [-GameDir <Undertale folder>] [-Uninstall] [-ShortcutDir <folder, default: desktop>]
# setup.ps1 (the installer window) loads it with -Library and calls Install-Mod / Uninstall-Mod.
# Every run adds to a log, %TEMP%\UndertaleEssentials-installer.log, for bug reports.
param([string]$GameDir = '', [switch]$Uninstall, [string]$ShortcutDir = '', [switch]$Library)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$PatchPath = Join-Path $Here 'data_framerate.patch'
$Version = '0.3.1 (early test)'
$ModFile = 'data_framerate.win'
$Shortcut = 'Undertale Essentials.lnk'
# file names from when the mod was called "Undertale Framerate Mod", kept so earlier installs
# still reinstall and uninstall cleanly
$Manifest = 'framerate_mod_installed.txt'
$OptionsBackup = 'options.ini.framerate_mod_backup'
$LogFile = Join-Path ([System.IO.Path]::GetTempPath()) 'UndertaleEssentials-installer.log'

# The installer window sets these: $Log receives each message, $Pump keeps the window responsive.
$script:Log = $null
$script:Pump = $null

# ---------- log file ----------

function Write-LogLine([string]$text) {
    # Logging must never stop an install, so any problem writing the log is ignored.
    try {
        if ((Test-Path -LiteralPath $LogFile) -and (Get-Item -LiteralPath $LogFile).Length -gt 1MB) {
            $keep = Get-Content -LiteralPath $LogFile -Tail 3000
            Set-Content -LiteralPath $LogFile -Value $keep -Encoding UTF8
        }
        Add-Content -LiteralPath $LogFile -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + '  ' + $text) -Encoding UTF8
    } catch {}
}

function Say([string]$text, [string]$color = 'Gray') {
    # A message for the player, on screen and in the log.
    if ($text -ne '') { Write-LogLine "  > $text" }
    if ($script:Log) { & $script:Log $text $color } else { Write-Host $text -ForegroundColor $color }
}

function Note([string]$text) {
    # A detail only for the log file (paths, checksums, timings).
    Write-LogLine "    $text"
}

function Get-Message($err) {
    # An error record's message on one line (some .NET messages end with a line break).
    return ($err.Exception.Message -replace '\s+', ' ').Trim()
}

function Note-Error($err) {
    # Everything known about an error record, for the log file.
    try {
        Note "ERROR: $($err.Exception.GetType().FullName): $(Get-Message $err)"
        if ($err.InvocationInfo -and $err.InvocationInfo.PositionMessage) {
            foreach ($l in ($err.InvocationInfo.PositionMessage -split "`r?`n")) { Note "  $l" }
        }
        if ($err.ScriptStackTrace) {
            foreach ($l in ($err.ScriptStackTrace -split "`r?`n")) { Note "  $l" }
        }
        $inner = $err.Exception.InnerException
        while ($inner) { Note "  caused by $($inner.GetType().FullName): $($inner.Message)"; $inner = $inner.InnerException }
    } catch {}
}

function Note-Start([string]$what) {
    # A header for each run: what's being done, and the system it runs on.
    Write-LogLine ''
    Write-LogLine "===== Undertale Essentials $Version - $what ====="
    try {
        $nt = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        # Windows 11 still calls itself Windows 10 here; its build numbers start at 22000
        $name = $nt.ProductName
        if ([int]$nt.CurrentBuild -ge 22000) { $name = $name -replace 'Windows 10', 'Windows 11' }
        Note "Windows: $name $($nt.DisplayVersion), build $($nt.CurrentBuild).$($nt.UBR)"
    } catch { Note "Windows: $([Environment]::OSVersion.VersionString)" }
    try {
        $admin = ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        Note "PowerShell $($PSVersionTable.PSVersion), .NET $([Environment]::Version), 64-bit: $([Environment]::Is64BitProcess), admin: $admin, culture: $((Get-Culture).Name)"
    } catch {}
    Note "installer files: $Here"
}

function Note-GameDir([string]$GameDir) {
    # What the game folder looks like now.
    try {
        Note "game folder: $GameDir"
        $dw = Join-Path $GameDir 'data.win'
        if (Test-Path -LiteralPath $dw) {
            $i = Get-Item -LiteralPath $dw
            Note "  data.win: $($i.Length) bytes, changed $($i.LastWriteTime.ToString('yyyy-MM-dd HH:mm')), SHA-1 $(Sha1 $dw)"
        } else { Note '  data.win: missing' }
        $mw = Join-Path $GameDir $ModFile
        if (Test-Path -LiteralPath $mw) { Note "  $($ModFile): $((Get-Item -LiteralPath $mw).Length) bytes" }
        $mf = Join-Path $GameDir $Manifest
        if (Test-Path -LiteralPath $mf) { Note "  install record: $((Get-Content -LiteralPath $mf) -join ' | ')" } else { Note '  install record: none' }
        $opt = Join-Path $GameDir 'options.ini'
        if (Test-Path -LiteralPath $opt) {
            $line = (Select-String -LiteralPath $opt -Pattern '^AlternateSyncMethod=' | Select-Object -First 1)
            Note "  options.ini: $(if ($line) { $line.Line.Trim() } else { 'no AlternateSyncMethod line' })"
        } else { Note '  options.ini: missing' }
        Note "  options.ini backup: $(Test-Path -LiteralPath (Join-Path $GameDir $OptionsBackup)), steam_appid.txt: $(Test-Path -LiteralPath (Join-Path $GameDir 'steam_appid.txt'))"
        Note "  Steam running: $([bool](Get-Process steam -ErrorAction SilentlyContinue))"
    } catch { Note-Error $_ }
}

# ---------- finding the game ----------

function Find-Undertale {
    $found = @()
    $steam = $null
    try { $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath } catch {}
    if ($steam) {
        $steam = $steam -replace '/', '\'
        $libs = @($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches)) {
                foreach ($g in $m.Matches) { $libs += ($g.Groups[1].Value -replace '\\\\', '\') }
            }
        }
        foreach ($lib in ($libs | Select-Object -Unique)) {
            $p = Join-Path $lib 'steamapps\common\Undertale'
            if (Test-Path (Join-Path $p 'UNDERTALE.exe')) { $found += $p }
        }
    }
    Note "Steam folder: $(if ($steam) { $steam } else { 'not found' }); Undertale found in: $(if ($found.Count) { $found -join ', ' } else { 'none' })"
    return $found
}

function Ask-GameDir {
    $found = @(Find-Undertale)
    if ($found.Count -gt 0) {
        Say "Found Undertale here:" 'White'
        Say "  $($found[0])" 'Yellow'
        Say ''
        $answer = Read-Host 'Press Enter to continue (or type N and Enter to pick another folder)'
        if ($answer -eq '' -or $answer -match '^[Yy]') { return $found[0] }
    }
    Say ''
    Say 'Paste the Undertale folder (in Steam: right-click Undertale > Manage > Browse local files,' 'White'
    Say 'then copy the address bar), and press Enter:' 'White'
    return (Read-Host 'Folder').Trim('"', ' ')
}

# ---------- the patch ----------

function Sha1([string]$path) { (Get-FileHash -Algorithm SHA1 -LiteralPath $path).Hash.ToLower() }

function Read-PatchInfo {
    # The patch file's header: the SHA-1 of the data.win it needs and of the file it makes.
    # $null (with a message) if it's missing or damaged.
    if (-not (Test-Path -LiteralPath $PatchPath)) {
        Say "Can't find the mod's files. Unzip the whole folder first (right-click the zip > Extract All)," 'Red'
        Say 'then run Install.bat from the unzipped folder. Nothing was changed.' 'Red'
        Note "missing: $PatchPath"
        return $null
    }
    $patch = [System.IO.File]::ReadAllBytes($PatchPath)
    if ($patch.Count -lt 60 -or [System.Text.Encoding]::ASCII.GetString($patch, 0, 11) -ne "UTFLPATCH1`n") {
        Say 'The mod''s patch file is damaged. Download the zip again and unzip it fresh. Nothing was changed.' 'Red'
        Note "bad patch header, $($patch.Count) bytes"
        return $null
    }
    return @{
        Bytes = $patch
        Orig = (($patch[11..30] | ForEach-Object { $_.ToString('x2') }) -join '')
        New = (($patch[31..50] | ForEach-Object { $_.ToString('x2') }) -join '')
    }
}

function Get-DataWinState([string]$GameDir, $info) {
    # 'ok' (the Steam v1.08 data.win), 'missing', 'modded' (already the mod's file) or 'other'.
    $dw = Join-Path $GameDir 'data.win'
    if (-not (Test-Path -LiteralPath $dw)) { return 'missing' }
    $h = Sha1 $dw
    if ($h -eq $info.Orig) { return 'ok' }
    if ($h -eq $info.New) { return 'modded' }
    return 'other'
}

function Say-DataWinProblem([string]$state) {
    $verify = 'In Steam: right-click Undertale > Properties > Installed Files > Verify integrity of game files, then try again.'
    switch ($state) {
        'missing' { Say "There's no data.win in this folder, so it isn't a complete Undertale install." 'Red' }
        'modded' { Say 'This folder''s data.win has already been replaced with a modded one (not by this installer).' 'Red' }
        default {
            Say "This folder's data.win isn't the one from Undertale v1.08 on Steam (another version, or another" 'Red'
            Say 'mod changed it). This mod only works with the Steam version.' 'Red'
        }
    }
    Say $verify 'White'
    Say 'Nothing was changed.' 'Red'
}

function Apply-Patch([string]$origPath, [string]$outPath, $patch) {
    $orig = [System.IO.File]::OpenRead($origPath)
    $out = [System.IO.File]::Create($outPath)
    try {
        [int]$bodyLen = $patch.Count - 59
        $ms = [System.IO.MemoryStream]::new($patch, 59, $bodyLen)
        $ds = [System.IO.Compression.DeflateStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
        $br = [System.IO.BinaryReader]::new($ds)
        $buf = [byte[]]::new(1048576)
        $ops = 0
        while ($true) {
            $ops += 1
            if ($script:Pump -and ($ops % 200) -eq 0) { & $script:Pump }
            $t = $ds.ReadByte()
            if ($t -lt 0) { break }
            if ($t -eq 67) {
                # C: copy from the original
                $off = [int64]$br.ReadUInt64()
                $left = [int64]$br.ReadUInt64()
                $orig.Position = $off
                while ($left -gt 0) {
                    $n = $orig.Read($buf, 0, [int][Math]::Min($left, $buf.Length))
                    if ($n -le 0) { throw 'original file ended early' }
                    $out.Write($buf, 0, $n)
                    $left -= $n
                }
            } elseif ($t -eq 73) {
                # I: new bytes stored in the patch
                $left = [int64]$br.ReadUInt64()
                while ($left -gt 0) {
                    $chunk = $br.ReadBytes([int][Math]::Min($left, $buf.Length))
                    if ($chunk.Length -le 0) { throw 'patch ended early' }
                    $out.Write($chunk, 0, $chunk.Length)
                    $left -= $chunk.Length
                }
            } else {
                throw "patch file is damaged (bad operation $t)"
            }
        }
    } finally {
        $out.Close()
        $orig.Close()
    }
}

# ---------- checks before changing anything ----------

function Test-GameRunning([string]$GameDir) {
    # Whether UNDERTALE.exe is running from this folder (its files can't be replaced then).
    $full = [System.IO.Path]::GetFullPath($GameDir).TrimEnd('\')
    foreach ($p in @(Get-Process UNDERTALE -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $p.Path } catch {}
        if (-not $path) { Note "UNDERTALE.exe is running (pid $($p.Id)), its folder couldn't be read"; return $true }
        if ([System.IO.Path]::GetDirectoryName($path).TrimEnd('\') -ieq $full) { Note "UNDERTALE.exe is running from this folder (pid $($p.Id))"; return $true }
    }
    return $false
}

function Test-CanChange([string]$GameDir, [int64]$needBytes = 0) {
    # Undertale closed, the folder writable and (when needBytes is given) room on the disk.
    # $true, or $false after saying what's wrong.
    if (Test-GameRunning $GameDir) {
        Say 'Undertale is running from this folder. Close the game first, then try again.' 'Red'
        Say 'Nothing was changed.' 'Red'
        return $false
    }
    $probe = Join-Path $GameDir '.undertale_essentials_write_test'
    try {
        [System.IO.File]::WriteAllText($probe, 'test')
        Remove-Item -LiteralPath $probe -Force
    } catch {
        Note-Error $_
        Say "Windows didn't let the installer change files in this folder:" 'Red'
        Say "  $(Get-Message $_)" 'Red'
        Say 'Close Undertale, then try again. If it still happens, right-click Install.bat >' 'White'
        Say 'Run as administrator.' 'White'
        Say 'Nothing was changed.' 'Red'
        return $false
    }
    if ($needBytes -gt 0) {
        try {
            $root = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($GameDir))
            $free = ([System.IO.DriveInfo]::new($root)).AvailableFreeSpace
            Note "free space on $($root): $([math]::Round($free / 1MB)) MB, needed about $([math]::Round($needBytes / 1MB)) MB"
            if ($free -lt $needBytes) {
                Say "There isn't enough free space on drive $root (about $([math]::Ceiling($needBytes / 1MB)) MB is needed)." 'Red'
                Say 'Nothing was changed.' 'Red'
                return $false
            }
        } catch { Note "couldn't check free space: $(Get-Message $_)" }
    }
    return $true
}

# ---------- install record ----------

function Read-Manifest([string]$GameDir) {
    $mf = Join-Path $GameDir $Manifest
    if (Test-Path -LiteralPath $mf) { return @(Get-Content -LiteralPath $mf | Where-Object { $_ -ne '' }) }
    return @()
}

function Save-Manifest([string]$GameDir, [string[]]$items) {
    [System.IO.File]::WriteAllLines((Join-Path $GameDir $Manifest), [string[]]@($items | Select-Object -Unique))
}

function Test-Installed([string]$GameDir) { Test-Path -LiteralPath (Join-Path $GameDir $Manifest) }

# ---------- uninstall ----------

function Uninstall-Mod([string]$GameDir) {
    # Removes what the install record lists and puts the original options.ini back. $true when done.
    # Anything it can't remove stays in the record, so running it again finishes the job.
    Note-Start 'uninstall'
    Note-GameDir $GameDir
    $mf = Join-Path $GameDir $Manifest
    if (-not (Test-Path -LiteralPath $mf)) {
        Say 'The mod is not installed in that folder (no install record found). Nothing was changed.' 'Yellow'
        return $false
    }
    if (-not (Test-CanChange $GameDir)) { return $false }
    $left = @()
    foreach ($name in (Read-Manifest $GameDir)) {
        try {
            if ($name -like 'shortcut=*.lnk') {
                # the desktop shortcut, stored with its full path
                $lnk = $name.Substring(9)
                if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force; Say 'Removed the desktop shortcut' }
            } elseif ($name -notmatch '[\\/]') {
                $p = Join-Path $GameDir $name
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Say "Removed $name" }
            } else {
                Note "skipped an unexpected install record line: $name"
            }
        } catch {
            Note-Error $_
            Say "Couldn't remove $($name -replace '^shortcut=', ''): $(Get-Message $_)" 'Yellow'
            $left += $name
        }
    }
    $ob = Join-Path $GameDir $OptionsBackup
    if (Test-Path -LiteralPath $ob) {
        try {
            Move-Item -LiteralPath $ob -Destination (Join-Path $GameDir 'options.ini') -Force
            Say 'Put back the original options.ini'
        } catch {
            Note-Error $_
            Say "Couldn't put back the original options.ini: $(Get-Message $_)" 'Yellow'
            $left += 'options.ini'
        }
    }
    if ($left.Count -gt 0) {
        # keep a record of what's left (options.ini isn't a record line: its backup file is the record)
        try { Save-Manifest $GameDir @($left | Where-Object { $_ -ne 'options.ini' }) } catch { Note-Error $_ }
        Say ''
        Say 'Some of the mod is still there (see above). Close Undertale, then uninstall again.' 'Red'
        Say "Details are in $LogFile" 'Gray'
        return $false
    }
    Remove-Item -LiteralPath $mf -Force
    Say ''
    Say 'Uninstalled. Undertale is back to how it was, and your saves are untouched.' 'Green'
    return $true
}

# ---------- install ----------

function Undo-Changes([string]$GameDir, $undo) {
    # Takes back this run's changes, newest first. $true if all of it worked.
    $ok = $true
    for ($i = $undo.Count - 1; $i -ge 0; $i--) {
        $u = $undo[$i]
        try {
            switch ($u.Kind) {
                'remove' { if (Test-Path -LiteralPath $u.Path) { Remove-Item -LiteralPath $u.Path -Force } }
                'restore' { [System.IO.File]::WriteAllText($u.Path, $u.Text) }
                'manifest' {
                    if ($null -eq $u.Lines) { Remove-Item -LiteralPath (Join-Path $GameDir $Manifest) -Force -ErrorAction SilentlyContinue }
                    else { Save-Manifest $GameDir $u.Lines }
                }
            }
            Note "undid: $(if ($u.Kind -eq 'manifest') { 'install record' } else { "$($u.Kind) $($u.Path)" })"
        } catch {
            $ok = $false
            Note-Error $_
        }
    }
    return $ok
}

function Install-Mod([string]$GameDir, [string]$ShortcutDir = '') {
    # Builds data_framerate.win, sets options.ini, adds the shortcut and the install record.
    # $true when done. On a problem it says why; if something already changed, it's undone.
    Note-Start 'install'
    Note-GameDir $GameDir
    $info = Read-PatchInfo
    if (-not $info) { return $false }
    Note "patch: needs data.win $($info.Orig), makes $($info.New)"

    Say 'Checking your data.win...'
    $state = Get-DataWinState $GameDir $info
    if ($state -ne 'ok') { Note "data.win check: $state"; Say-DataWinProblem $state; return $false }
    $dataWin = Join-Path $GameDir 'data.win'
    if (-not (Test-CanChange $GameDir ((Get-Item -LiteralPath $dataWin).Length + 16MB))) { return $false }

    $target = Join-Path $GameDir $ModFile
    $tmp = "$target.tmp"
    $before = Read-Manifest $GameDir
    $undo = New-Object System.Collections.ArrayList
    [void]$undo.Add(@{ Kind = 'manifest'; Lines = $(if ((Test-Installed $GameDir)) { $before } else { $null }) })
    $step = ''
    try {
        $step = 'building data_framerate.win'
        Say 'Building data_framerate.win from your data.win (this takes a few seconds)...'
        $t0 = Get-Date
        try {
            Apply-Patch $dataWin $tmp $info.Bytes
        } catch {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
            throw
        }
        Note "patched in $([math]::Round(((Get-Date) - $t0).TotalSeconds, 1)) s"
        $got = Sha1 $tmp
        if ($got -ne $info.New) {
            Remove-Item -LiteralPath $tmp -Force
            Note "result SHA-1 $got, expected $($info.New)"
            Say 'The built file did not check out (the download may be damaged), so it was not installed.' 'Red'
            Say 'Download the zip again and unzip it fresh. Nothing was changed.' 'Red'
            return $false
        }
        $step = 'putting data_framerate.win in place'
        # if the move fails, the built file mustn't stay behind (it's as big as data.win)
        [void]$undo.Add(@{ Kind = 'remove'; Path = $tmp })
        if (-not (Test-Path -LiteralPath $target)) { [void]$undo.Add(@{ Kind = 'remove'; Path = $target }) }
        Move-Item -LiteralPath $tmp -Destination $target -Force
        # recorded right away, so even an install that stops here can be uninstalled
        $record = @($before) + @($ModFile)
        Save-Manifest $GameDir $record

        # options.ini: turn off GameMaker's alternate sync method (see the top of this file). The
        # backup is made once, so installing again never overwrites the original.
        $step = 'changing options.ini'
        $opt = Join-Path $GameDir 'options.ini'
        if (Test-Path -LiteralPath $opt) {
            $text = [System.IO.File]::ReadAllText($opt)
            if ($text -match '(?m)^AlternateSyncMethod=1\s*$') {
                $ob = Join-Path $GameDir $OptionsBackup
                if (-not (Test-Path -LiteralPath $ob)) {
                    Copy-Item -LiteralPath $opt -Destination $ob
                    [void]$undo.Add(@{ Kind = 'remove'; Path = $ob })
                }
                [void]$undo.Add(@{ Kind = 'restore'; Path = $opt; Text = $text })
                [System.IO.File]::WriteAllText($opt, ($text -replace '(?m)^AlternateSyncMethod=1', 'AlternateSyncMethod=0'))
                Note 'options.ini: AlternateSyncMethod set to 0'
            }
        }

        # Lets UNDERTALE.exe start directly (from the shortcut) without Steam restarting it.
        $step = 'adding steam_appid.txt'
        $appid = Join-Path $GameDir 'steam_appid.txt'
        if (-not (Test-Path -LiteralPath $appid)) {
            [System.IO.File]::WriteAllText($appid, '391540')
            [void]$undo.Add(@{ Kind = 'remove'; Path = $appid })
            $record += 'steam_appid.txt'
        }

        # The shortcut is a convenience: if Windows won't make it, the install still counts.
        $step = 'making the desktop shortcut'
        if ($ShortcutDir -eq '') { $ShortcutDir = [Environment]::GetFolderPath('Desktop') }
        $lnk = Join-Path $ShortcutDir $Shortcut
        $exe = Join-Path $GameDir 'UNDERTALE.exe'
        $madeShortcut = $false
        try {
            $hadShortcut = Test-Path -LiteralPath $lnk
            $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            $sc.TargetPath = $exe
            $sc.Arguments = "-game $ModFile"
            $sc.WorkingDirectory = $GameDir
            $sc.IconLocation = "$exe,0"
            $sc.Description = 'Undertale with Undertale Essentials'
            $sc.Save()
            if (-not $hadShortcut) { [void]$undo.Add(@{ Kind = 'remove'; Path = $lnk }) }
            $record += "shortcut=$lnk"
            $madeShortcut = $true
            Note "shortcut: $lnk"
        } catch {
            Note-Error $_
            Say "Couldn't make the desktop shortcut ($(Get-Message $_))." 'Yellow'
            Say 'The mod is still installed: start it with the installer''s Play button, or run' 'Yellow'
            Say "  UNDERTALE.exe -game $ModFile  in the game folder." 'Yellow'
        }

        $step = 'saving the install record'
        Save-Manifest $GameDir $record
    } catch {
        $err = $_
        Note "failed while $step"
        Note-Error $err
        Say "Something went wrong while $($step): $(Get-Message $err)" 'Red'
        if ($err.Exception -is [System.IO.IOException] -or $err.Exception -is [System.UnauthorizedAccessException]) {
            Say 'A file may be in use (close Undertale) or blocked by antivirus.' 'Yellow'
        }
        if (Undo-Changes $GameDir $undo) {
            Say 'The changes made so far were undone. Nothing was changed.' 'Red'
        } else {
            Say 'Some changes could not be undone. Uninstall to clean up, or verify the game files in Steam.' 'Red'
        }
        Say "Details are in $LogFile" 'Gray'
        return $false
    }

    # Tidy up after an earlier install: its shortcut under the mod's earlier name is replaced by this
    # one (only once the new one exists). Not part of the install itself, so a problem is only noted.
    foreach ($name in $before) {
        if ($madeShortcut -and $name -like 'shortcut=*.lnk' -and $name -ne "shortcut=$lnk") {
            try {
                $p = $name.Substring(9)
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Say 'Replaced the old desktop shortcut' }
                Save-Manifest $GameDir @((Read-Manifest $GameDir) | Where-Object { $_ -ne $name })
            } catch { Note-Error $_ }
        }
    }
    Note 'install finished'
    return $true
}

if ($Library) { return }

# ---------- console version (Uninstall.bat, or install.ps1 run directly) ----------

try {
    Write-Host ''
    Write-Host "  UNDERTALE ESSENTIALS  $Version" -ForegroundColor Yellow
    Write-Host '  Early test version: expect bugs and issues.' -ForegroundColor Yellow
    Write-Host ''
    if ($GameDir -eq '') { $GameDir = Ask-GameDir }
    $GameDir = $GameDir.Trim().Trim('"')
    if ($GameDir -eq '' -or -not (Test-Path -LiteralPath (Join-Path $GameDir 'UNDERTALE.exe'))) {
        Say "UNDERTALE.exe isn't in that folder: $GameDir" 'Red'
        Say 'Nothing was changed.' 'Red'
        exit 1
    }
    if ($Uninstall) {
        if (Uninstall-Mod $GameDir) { exit 0 } else { exit 1 }
    }
    if (-not (Install-Mod $GameDir $ShortcutDir)) { exit 1 }
    Say ''
    Say 'Installed!' 'Green'
    Say ''
    Say 'To play: make sure Steam is running, then double-click' 'White'
    Say '  "Undertale Essentials" on your desktop.' 'Yellow'
    Say 'In game, press F1 for the mod settings.' 'White'
    exit 0
} catch {
    Note-Error $_
    Say ''
    Say "The installer stopped because of an error: $(Get-Message $_)" 'Red'
    Say "Details are in $LogFile" 'Gray'
    exit 1
}
