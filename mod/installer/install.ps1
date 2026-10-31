# Undertale Framerate Mod. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
# Undertale Framerate Mod - installer / uninstaller.
# Builds data_framerate.win from the player's own data.win using data_framerate.patch, and adds a
# desktop shortcut that starts it. The only Undertale file it changes is options.ini (one setting,
# with a backup that uninstalling puts back): GameMaker's AlternateSyncMethod=1 locks every frame to
# the monitor's refresh, which caps the mod at the refresh rate and makes lower caps uneven.
#   install.ps1 [-GameDir <Undertale folder>] [-Uninstall] [-ShortcutDir <folder, default: desktop>]
param([string]$GameDir = '', [switch]$Uninstall, [string]$ShortcutDir = '')

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$PatchPath = Join-Path $Here 'data_framerate.patch'
$Version = '0.1 (early test)'
$ModFile = 'data_framerate.win'
$Shortcut = 'Undertale (Framerate Mod).lnk'
$Manifest = 'framerate_mod_installed.txt'
$OptionsBackup = 'options.ini.framerate_mod_backup'

function Say([string]$text, [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }

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

function Sha1([string]$path) { (Get-FileHash -Algorithm SHA1 -LiteralPath $path).Hash.ToLower() }

function Apply-Patch([string]$origPath, [string]$outPath, $patch) {
    $orig = [System.IO.File]::OpenRead($origPath)
    $out = [System.IO.File]::Create($outPath)
    try {
        [int]$bodyLen = $patch.Count - 59
        $ms = [System.IO.MemoryStream]::new($patch, 59, $bodyLen)
        $ds = [System.IO.Compression.DeflateStream]::new($ms, [System.IO.Compression.CompressionMode]::Decompress)
        $br = [System.IO.BinaryReader]::new($ds)
        $buf = [byte[]]::new(1048576)
        while ($true) {
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

Say ''
Say "  UNDERTALE FRAMERATE MOD  $Version" 'Yellow'
Say '  Early test version: expect bugs and issues.' 'Yellow'
Say ''

if ($GameDir -eq '') { $GameDir = Ask-GameDir }
if (-not (Test-Path (Join-Path $GameDir 'UNDERTALE.exe'))) {
    Say "UNDERTALE.exe isn't in that folder: $GameDir" 'Red'
    Say 'Nothing was changed.' 'Red'
    exit 1
}

if ($Uninstall) {
    $mf = Join-Path $GameDir $Manifest
    if (-not (Test-Path $mf)) {
        Say 'The mod is not installed in that folder (no install record found). Nothing was changed.' 'Yellow'
        exit 0
    }
    foreach ($name in (Get-Content $mf)) {
        if ($name -like 'shortcut=*.lnk') {
            # the desktop shortcut, stored with its full path
            $lnk = $name.Substring(9)
            if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk; Say 'Removed the desktop shortcut' }
        } elseif ($name -and $name -notmatch '[\\/]' -and (Test-Path (Join-Path $GameDir $name))) {
            Remove-Item -LiteralPath (Join-Path $GameDir $name)
            Say "Removed $name"
        }
    }
    $ob = Join-Path $GameDir $OptionsBackup
    if (Test-Path -LiteralPath $ob) {
        Move-Item -LiteralPath $ob -Destination (Join-Path $GameDir 'options.ini') -Force
        Say 'Put back the original options.ini'
    }
    Remove-Item -LiteralPath $mf
    Say ''
    Say 'Uninstalled. Undertale is back to how it was, and your saves are untouched.' 'Green'
    exit 0
}

if (-not (Test-Path $PatchPath)) {
    Say "Can't find the mod's files. Unzip the whole folder first (right-click the zip > Extract All)," 'Red'
    Say 'then run Install.bat from the unzipped folder. Nothing was changed.' 'Red'
    exit 1
}
$patch = [System.IO.File]::ReadAllBytes($PatchPath)
$magic = [System.Text.Encoding]::ASCII.GetString($patch, 0, 11)
if ($magic -ne "UTFLPATCH1`n") { Say 'The patch file is damaged.' 'Red'; exit 1 }
$wantOrig = (($patch[11..30] | ForEach-Object { $_.ToString('x2') }) -join '')
$wantNew = (($patch[31..50] | ForEach-Object { $_.ToString('x2') }) -join '')

$dataWin = Join-Path $GameDir 'data.win'
Say 'Checking your data.win...'
if (-not (Test-Path $dataWin) -or (Sha1 $dataWin) -ne $wantOrig) {
    Say ''
    Say "This mod needs the Steam version of Undertale (v1.08), and this folder's data.win" 'Red'
    Say "doesn't match it. If Steam has an update pending, update and try again." 'Red'
    Say 'Nothing was changed.' 'Red'
    exit 1
}

$target = Join-Path $GameDir $ModFile
$tmp = "$target.tmp"
Say 'Building data_framerate.win from your data.win (this takes a few seconds)...'
Apply-Patch $dataWin $tmp $patch
if ((Sha1 $tmp) -ne $wantNew) {
    Remove-Item -LiteralPath $tmp
    Say 'The result did not check out, so it was not installed. Nothing was changed.' 'Red'
    exit 1
}
Move-Item -LiteralPath $tmp -Destination $target -Force
$created = @($ModFile)

# options.ini: turn off GameMaker's alternate sync method (see the top of this file). The backup is
# made once, so installing again never overwrites the original.
$opt = Join-Path $GameDir 'options.ini'
if (Test-Path -LiteralPath $opt) {
    $text = [System.IO.File]::ReadAllText($opt)
    if ($text -match '(?m)^AlternateSyncMethod=1\s*$') {
        $ob = Join-Path $GameDir $OptionsBackup
        if (-not (Test-Path -LiteralPath $ob)) { Copy-Item -LiteralPath $opt -Destination $ob }
        [System.IO.File]::WriteAllText($opt, ($text -replace '(?m)^AlternateSyncMethod=1', 'AlternateSyncMethod=0'))
    }
}

# Lets UNDERTALE.exe start directly (from the shortcut) without Steam restarting it.
$appid = Join-Path $GameDir 'steam_appid.txt'
if (-not (Test-Path $appid)) {
    [System.IO.File]::WriteAllText($appid, '391540')
    $created += 'steam_appid.txt'
}

if ($ShortcutDir -eq '') { $ShortcutDir = [Environment]::GetFolderPath('Desktop') }
$lnk = Join-Path $ShortcutDir $Shortcut
$exe = Join-Path $GameDir 'UNDERTALE.exe'
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.Arguments = "-game $ModFile"
$sc.WorkingDirectory = $GameDir
$sc.IconLocation = "$exe,0"
$sc.Description = 'Undertale with the framerate mod'
$sc.Save()
$created += "shortcut=$lnk"
# installing again keeps the record of what an earlier install added
$mf = Join-Path $GameDir $Manifest
if (Test-Path $mf) { $created = @(Get-Content $mf) + $created | Select-Object -Unique }
[System.IO.File]::WriteAllLines($mf, [string[]]$created)

Say ''
Say 'Installed!' 'Green'
Say ''
Say 'To play: make sure Steam is running, then double-click' 'White'
Say '  "Undertale (Framerate Mod)" on your desktop.' 'Yellow'
Say 'In game, press F1 for the mod settings.' 'White'
exit 0
