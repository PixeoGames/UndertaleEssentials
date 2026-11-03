# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
# Undertale Essentials - installer window. Install.bat opens it; the work itself is install.ps1's
# Install-Mod and Uninstall-Mod, the same as the console version. Both write to the same log,
# %TEMP%\UndertaleEssentials-installer.log.
#   setup.ps1 [<Undertale folder>]
# For testing: -ShortcutDir (default: desktop), -SaveDir (default: %LOCALAPPDATA%\UNDERTALE) and
# -BackupRoot (default: Documents\Undertale save backups).
# Exit code: 0 when the window was closed normally, 1 when it couldn't start or stopped on an error
# (Install.bat then shows its console and offers the console installer).
param([string]$GameDir = '', [string]$ShortcutDir = '', [string]$SaveDir = '', [string]$BackupRoot = '')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
# the same file install.ps1 logs to (repeated here so errors before it loads are logged too)
$EarlyLog = Join-Path ([System.IO.Path]::GetTempPath()) 'UndertaleEssentials-installer.log'

$console = [System.IntPtr]::Zero
try {
    Add-Type -Namespace UESetup -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
'@
    # Hide the console window (Install.bat's), so only the installer window shows. Started hidden,
    # Windows would also hide the process's first window shown normally, which would be the
    # installer window: hiding the console first uses that up.
    $console = [UESetup.Win]::GetConsoleWindow()
    if ($console -ne [System.IntPtr]::Zero) { [UESetup.Win]::ShowWindow($console, 0) | Out-Null }
    # sharp text on scaled (high-DPI) screens
    [UESetup.Win]::SetProcessDPIAware() | Out-Null
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

function Show-Fatal([string]$text) {
    [System.Windows.Forms.MessageBox]::Show($text, 'Undertale Essentials', 'OK', 'Error') | Out-Null
}

function Exit-Fatal([string]$text) {
    # Can't go on: say why, bring Install.bat's console back (it offers the console installer) and
    # stop with exit code 1.
    try { Add-Content -LiteralPath $EarlyLog -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + "  installer window: $text") -Encoding UTF8 } catch {}
    Show-Fatal $text
    try { if ($console -ne [System.IntPtr]::Zero) { [UESetup.Win]::ShowWindow($console, 5) | Out-Null } } catch {}
    exit 1
}

# install.ps1's own parameters (GameDir, ShortcutDir...) land in this scope too: keep ours first
$StartFolder = $GameDir
$ShortcutFolder = $ShortcutDir
try {
    . (Join-Path $PSScriptRoot 'install.ps1') -Library
} catch {
    Exit-Fatal "The installer's files are missing or damaged. Unzip the whole folder first (right-click the zip > Extract All), then run Install.bat from the unzipped folder.`n`n$($_.Exception.Message)"
}
Note-Start 'installer window'

# An error inside a button or other event: say so plainly and log the details (instead of WinForms'
# own "Unhandled exception" box).
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $e)
    $ex = $e.Exception
    $msg = ($ex.Message -replace '\s+', ' ').Trim()
    Note "unexpected error in the installer window: $($ex.GetType().FullName): $msg"
    if ($ex.ErrorRecord) { Note-Error $ex.ErrorRecord } else { Note $ex.ToString() }
    Show-Fatal "Something went wrong in the installer:`n`n$msg`n`nThe details are in $LogFile. You can attach it to a bug report (or use ""Copy details for a bug report"")."
})

if ($SaveDir -eq '') { $SaveDir = Join-Path $env:LOCALAPPDATA 'UNDERTALE' }
if ($BackupRoot -eq '') { $BackupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Undertale save backups' }
$Yellow = [System.Drawing.Color]::FromArgb(255, 255, 0)
$Grey = [System.Drawing.Color]::FromArgb(160, 160, 160)
$Red = [System.Drawing.Color]::FromArgb(255, 110, 110)
$Green = [System.Drawing.Color]::FromArgb(110, 230, 110)
$Back = [System.Drawing.Color]::Black
$Panel = [System.Drawing.Color]::FromArgb(24, 24, 24)

$Scale = 1.0
try { $g = [System.Drawing.Graphics]::FromHwnd([System.IntPtr]::Zero); $Scale = $g.DpiX / 96; $g.Dispose() } catch {}
Note "screen scale: $([math]::Round($Scale * 100))%"
function Pt([int]$x, [int]$y) { New-Object System.Drawing.Point([int][math]::Round($x * $Scale), [int][math]::Round($y * $Scale)) }
function Sz([int]$w, [int]$h) { New-Object System.Drawing.Size([int][math]::Round($w * $Scale), [int][math]::Round($h * $Scale)) }

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Undertale Essentials Setup'
# Sizes below are for a 100% screen. WinForms' own scaling doesn't resize controls made from
# PowerShell, while text does grow with the screen's scaling, so every position and size goes
# through Pt / Sz, which scale by the screen's DPI (the process is DPI-aware, see above).
$form.AutoScaleMode = 'None'
$form.ClientSize = Sz 640 548
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.BackColor = $Back
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

function Add-Label([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, $font = $null, $color = $null) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = Pt $x $y
    $l.Size = Sz $w $h
    if ($font) { $l.Font = $font }
    if ($color) { $l.ForeColor = $color }
    $form.Controls.Add($l)
    return $l
}

function Add-Button([string]$text, [int]$x, [int]$y, [int]$w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = Pt $x $y
    $b.Size = Sz $w 34
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::White
    $b.BackColor = $Back
    $b.ForeColor = [System.Drawing.Color]::White
    # Windows draws a disabled button's text from its background, so on black it would vanish
    $b.Add_EnabledChanged({
        $this.BackColor = if ($this.Enabled) { $Back } else { [System.Drawing.Color]::FromArgb(64, 64, 64) }
        $this.FlatAppearance.BorderColor = if ($this.Enabled) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::FromArgb(96, 96, 96) }
    })
    $form.Controls.Add($b)
    return $b
}

function Add-Link([string]$text, [int]$x, [int]$y, [int]$w) {
    # a borderless button that looks like a link (it can also be reached with Tab and Enter)
    $l = New-Object System.Windows.Forms.Button
    $l.Text = $text
    $l.Location = Pt $x $y
    $l.Size = Sz $w 24
    $l.FlatStyle = 'Flat'
    $l.FlatAppearance.BorderSize = 0
    $l.FlatAppearance.MouseOverBackColor = $Panel
    $l.FlatAppearance.MouseDownBackColor = $Panel
    $l.BackColor = $Back
    $l.ForeColor = $Grey
    $l.TextAlign = 'MiddleLeft'
    $l.Cursor = [System.Windows.Forms.Cursors]::Hand
    $l.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Underline)
    $form.Controls.Add($l)
    return $l
}

Add-Label 'UNDERTALE ESSENTIALS' 20 14 600 40 (New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)) | Out-Null
Add-Label "Version $Version" 22 54 600 22 $null $Grey | Out-Null
Add-Label ("Early test version: bugs, crashes and lost saves are possible. " +
    "Back up your saves first (the button below does it for you).") 22 82 600 44 $null $Yellow | Out-Null

Add-Label 'Undertale folder' 22 136 600 22 | Out-Null
$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = Pt 22 160
$txtFolder.Size = Sz 490 26
$txtFolder.BackColor = $Panel
$txtFolder.ForeColor = [System.Drawing.Color]::White
$txtFolder.BorderStyle = 'FixedSingle'
$form.Controls.Add($txtFolder)
$btnBrowse = Add-Button 'Browse...' 522 157 96

$lblStatus = Add-Label '' 22 194 600 22

$btnInstall = Add-Button 'Install' 22 228 140
$btnUninstall = Add-Button 'Uninstall' 172 228 140
$btnBackup = Add-Button 'Back up my saves' 322 228 160
$btnPlay = Add-Button 'Play' 492 228 126

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = Pt 22 276
$txtLog.Size = Sz 596 190
$txtLog.ReadOnly = $true
$txtLog.BackColor = $Panel
$txtLog.ForeColor = [System.Drawing.Color]::White
$txtLog.BorderStyle = 'None'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$form.Controls.Add($txtLog)

$lnkLog = Add-Link 'Open the installer log' 18 472 160
$lnkCopy = Add-Link 'Copy details for a bug report' 186 472 230

Add-Label 'Undertale Essentials is free software (GNU GPL v3). Undertale belongs to Toby Fox; this is a fan-made mod.' 22 508 600 30 (New-Object System.Drawing.Font('Segoe UI', 8.5)) $Grey | Out-Null

# install.ps1's messages go to the log box, in its colours
$script:Log = {
    param($text, $color)
    $c = switch ($color) {
        'Red' { $Red }
        'Green' { $Green }
        'Yellow' { $Yellow }
        'White' { [System.Drawing.Color]::White }
        default { [System.Drawing.Color]::FromArgb(200, 200, 200) }
    }
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionLength = 0
    $txtLog.SelectionColor = $c
    $txtLog.AppendText("$text`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}
$script:Pump = { [System.Windows.Forms.Application]::DoEvents() }

# The patch's header says which data.win it needs; read once. $null means the files are missing or
# damaged (Read-PatchInfo has said so in the log box).
$script:PatchInfo = Read-PatchInfo
$script:Checked = @{}

function Get-FolderState([string]$dir) {
    # data.win's state for this folder (see Get-DataWinState), remembered until data.win changes
    $dw = Join-Path $dir 'data.win'
    $key = $dir
    if (Test-Path -LiteralPath $dw) { $i = Get-Item -LiteralPath $dw; $key = "$dir|$($i.Length)|$($i.LastWriteTimeUtc.Ticks)" }
    if (-not $script:Checked.ContainsKey($key)) {
        $script:Checked[$key] = Get-DataWinState $dir $script:PatchInfo
        Note "status check: $dir -> data.win $($script:Checked[$key])"
    }
    return $script:Checked[$key]
}

function Update-Status {
    $dir = $txtFolder.Text.Trim().Trim('"')
    $hasGame = $false
    try { $hasGame = ($dir -ne '') -and (Test-Path -LiteralPath (Join-Path $dir 'UNDERTALE.exe')) } catch {}
    $installed = $hasGame -and (Test-Installed $dir)
    $state = ''
    if ($hasGame -and $script:PatchInfo) {
        try { $state = Get-FolderState $dir } catch { Note-Error $_; $state = 'unreadable' }
    }
    $lblStatus.ForeColor = [System.Drawing.Color]::White
    if (-not $script:PatchInfo) {
        $lblStatus.ForeColor = $Red
        $lblStatus.Text = "The installer's files are missing or damaged (see below)."
    } elseif (-not $hasGame) {
        $lblStatus.ForeColor = $Red
        $lblStatus.Text = if ($dir -eq '') { 'Choose your Undertale folder (Browse...).' } else { "UNDERTALE.exe isn't in this folder." }
    } elseif ($installed) {
        $lblStatus.ForeColor = $Green
        $lblStatus.Text = 'Undertale Essentials is installed in this folder.'
    } elseif ($state -eq 'ok') {
        $lblStatus.Text = 'Undertale v1.08 (Steam) found. Undertale Essentials is not installed here yet.'
    } else {
        $lblStatus.ForeColor = $Yellow
        $lblStatus.Text = switch ($state) {
            'missing' { "This folder has no data.win. Click Install for what to do." }
            'modded' { "This folder's data.win is already modded. Click Install for what to do." }
            default { "This folder's data.win isn't Undertale v1.08 from Steam. Click Install for what to do." }
        }
    }
    if ($hasGame -and -not $script:IconSet) {
        # the window gets Undertale's own icon
        try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $dir 'UNDERTALE.exe')); $script:IconSet = $true } catch {}
    }
    $btnInstall.Text = if ($installed) { 'Reinstall' } else { 'Install' }
    $btnInstall.Enabled = $hasGame -and [bool]$script:PatchInfo
    $btnUninstall.Enabled = $installed
    $btnPlay.Enabled = $installed -and (Test-Path -LiteralPath (Join-Path $dir $ModFile))
}

function Set-Busy([bool]$busy) {
    foreach ($b in $btnInstall, $btnUninstall, $btnBackup, $btnPlay, $btnBrowse) { $b.Enabled = -not $busy }
    $txtFolder.ReadOnly = $busy
    $form.Cursor = if ($busy) { [System.Windows.Forms.Cursors]::WaitCursor } else { [System.Windows.Forms.Cursors]::Default }
    if (-not $busy) { Update-Status }
}

# every button reports what went wrong instead of failing silently
function Run-Safely([string]$what, [scriptblock]$action) {
    Note "button: $what"
    Set-Busy $true
    try { & $action }
    catch {
        Note-Error $_
        Say "Something went wrong: $(Get-Message $_)" 'Red'
        Say "Details are in $LogFile" 'Gray'
    }
    finally { Set-Busy $false }
}

$txtFolder.Add_TextChanged({ Update-Status })

$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Choose your Undertale folder (the one with UNDERTALE.exe). In Steam: right-click Undertale > Manage > Browse local files.'
    if ($txtFolder.Text -ne '' -and (Test-Path -LiteralPath $txtFolder.Text)) { $d.SelectedPath = $txtFolder.Text }
    if ($d.ShowDialog($form) -eq 'OK') { $txtFolder.Text = $d.SelectedPath; Note "browsed to $($d.SelectedPath)" }
})

$btnInstall.Add_Click({
    Run-Safely 'Install' {
        $txtLog.Clear()
        $ok = Install-Mod $txtFolder.Text.Trim().Trim('"') $ShortcutFolder
        if ($ok -eq $true) {
            Say ''
            Say 'Installed!' 'Green'
            Say 'To play: make sure Steam is running, then click Play here,' 'White'
            Say 'or double-click "Undertale Essentials" on your desktop. In game, F1 opens the mod settings.' 'White'
        }
    }
})

$btnUninstall.Add_Click({
    $answer = [System.Windows.Forms.MessageBox]::Show($form,
        "Remove Undertale Essentials from this folder?`n`nUndertale goes back to how it was. Your saves are kept.",
        'Uninstall', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { Note 'uninstall cancelled'; return }
    Run-Safely 'Uninstall' {
        $txtLog.Clear()
        Uninstall-Mod $txtFolder.Text.Trim().Trim('"') | Out-Null
    }
})

$btnBackup.Add_Click({
    Run-Safely 'Back up my saves' {
        $txtLog.Clear()
        if (-not (Test-Path -LiteralPath $SaveDir)) {
            Say "No Undertale saves found yet (looked in $SaveDir)." 'Yellow'
            return
        }
        $dest = Join-Path $BackupRoot ('UNDERTALE ' + (Get-Date -Format 'yyyy-MM-dd HH.mm.ss'))
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
        Copy-Item -LiteralPath $SaveDir -Destination $dest -Recurse
        $n = @(Get-ChildItem -LiteralPath $dest -Recurse -File).Count
        Note "backed up $n files from $SaveDir to $dest"
        Say "Saves backed up ($n files) to:" 'Green'
        Say "  $dest" 'White'
        Say 'To restore them, copy the files from there back into:' 'Gray'
        Say "  $SaveDir" 'Gray'
        Start-Process explorer.exe -ArgumentList "`"$dest`""
    }
})

$btnPlay.Add_Click({
    Run-Safely 'Play' {
        if (-not (Get-Process steam -ErrorAction SilentlyContinue)) {
            Say 'Steam is not running. Start Steam first, then click Play again.' 'Yellow'
            return
        }
        $dir = $txtFolder.Text.Trim().Trim('"')
        Start-Process -FilePath (Join-Path $dir 'UNDERTALE.exe') -ArgumentList "-game $ModFile" -WorkingDirectory $dir
        Say 'Starting Undertale with Undertale Essentials...' 'Green'
    }
})

$lnkLog.Add_Click({
    if (Test-Path -LiteralPath $LogFile) { Start-Process notepad.exe -ArgumentList "`"$LogFile`"" }
    else { Say "There's no installer log yet ($LogFile)." 'Yellow' }
})

$lnkCopy.Add_Click({
    # What a bug report needs: versions, the folder's state and the latest log lines.
    try {
        $dir = $txtFolder.Text.Trim().Trim('"')
        $lines = @(
            "Undertale Essentials $Version installer",
            "Windows: $([Environment]::OSVersion.VersionString), PowerShell $($PSVersionTable.PSVersion)",
            "Folder: $dir",
            "Status: $($lblStatus.Text)",
            '',
            'Latest installer log lines:'
        )
        if (Test-Path -LiteralPath $LogFile) { $lines += @(Get-Content -LiteralPath $LogFile -Tail 60) }
        [System.Windows.Forms.Clipboard]::SetText(($lines -join "`r`n"))
        Say 'Copied the details. Paste them into the bug report (Ctrl+V).' 'Green'
    } catch {
        Note-Error $_
        Say "Couldn't copy the details ($(Get-Message $_)). The log file is $LogFile" 'Yellow'
    }
})

$form.Add_Shown({
    if ($StartFolder -ne '') {
        $txtFolder.Text = $StartFolder.Trim('"')
    } else {
        $found = @(Find-Undertale)
        if ($found.Count -gt 0) {
            $txtFolder.Text = $found[0]
            Say "Found Undertale in $($found[0])." 'Gray'
        } else {
            Say "Couldn't find Undertale by itself. Click Browse... and choose its folder" 'Yellow'
            Say '(in Steam: right-click Undertale > Manage > Browse local files).' 'Yellow'
        }
    }
    Update-Status
})

try {
    [System.Windows.Forms.Application]::Run($form)
} catch {
    Note-Error $_
    Exit-Fatal "The installer stopped because of an error:`n`n$($_.Exception.Message)`n`nThe details are in $LogFile."
}
Note 'installer window closed'
exit 0
