# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
# Undertale Essentials - installer window. Install.bat opens it; the work itself is install.ps1's
# Install-Mod and Uninstall-Mod, the same as the console version.
#   setup.ps1 [<Undertale folder>]
# For testing: -ShortcutDir (default: desktop), -SaveDir (default: %LOCALAPPDATA%\UNDERTALE) and
# -BackupRoot (default: Documents\Undertale save backups).
param([string]$GameDir = '', [string]$ShortcutDir = '', [string]$SaveDir = '', [string]$BackupRoot = '')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

function Show-Fatal([string]$text) {
    [System.Windows.Forms.MessageBox]::Show($text, 'Undertale Essentials', 'OK', 'Error') | Out-Null
}

try {
    Add-Type -Namespace UESetup -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
'@
    # Hide the console window. Started hidden (Install.bat), Windows would also hide the process's
    # first window shown normally, which would be the installer window: hiding the console first
    # uses that up.
    $console = [UESetup.Win]::GetConsoleWindow()
    if ($console -ne [System.IntPtr]::Zero) { [UESetup.Win]::ShowWindow($console, 0) | Out-Null }
    # sharp text on scaled (high-DPI) screens
    [UESetup.Win]::SetProcessDPIAware() | Out-Null
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

# An error inside a button or other event: say so plainly, and keep the details in a file for a bug
# report (instead of WinForms' own "Unhandled exception" box).
$ErrorFile = Join-Path $env:TEMP 'UndertaleEssentials_setup_error.txt'
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $e)
    $ex = $e.Exception
    $where = ''
    if ($ex.ErrorRecord) { $where = $ex.ErrorRecord.ScriptStackTrace }
    try { Set-Content -LiteralPath $ErrorFile -Value "$($ex.Message)`r`n$where`r`n$($ex.ToString())" } catch {}
    Show-Fatal "Something went wrong in the installer:`n`n$($ex.Message)`n`nThe details are in $ErrorFile (please attach it to a bug report)."
})

# install.ps1's own parameters (GameDir, ShortcutDir...) land in this scope too: keep ours first
$StartFolder = $GameDir
$ShortcutFolder = $ShortcutDir
try {
    . (Join-Path $PSScriptRoot 'install.ps1') -Library
} catch {
    Show-Fatal "The installer's files are missing. Unzip the whole folder first (right-click the zip > Extract All), then run Install.bat from the unzipped folder.`n`n$($_.Exception.Message)"
    exit 1
}

if ($SaveDir -eq '') { $SaveDir = Join-Path $env:LOCALAPPDATA 'UNDERTALE' }
if ($BackupRoot -eq '') { $BackupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Undertale save backups' }
$Yellow = [System.Drawing.Color]::FromArgb(255, 255, 0)
$Grey = [System.Drawing.Color]::FromArgb(160, 160, 160)
$Back = [System.Drawing.Color]::Black
$Panel = [System.Drawing.Color]::FromArgb(24, 24, 24)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Undertale Essentials Setup'
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
$form.AutoScaleMode = 'Dpi'
$form.ClientSize = New-Object System.Drawing.Size(640, 520)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.BackColor = $Back
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

function Add-Label([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, $font = $null, $color = $null) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    if ($font) { $l.Font = $font }
    if ($color) { $l.ForeColor = $color }
    $form.Controls.Add($l)
    return $l
}

function Add-Button([string]$text, [int]$x, [int]$y, [int]$w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, 34)
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

Add-Label 'UNDERTALE ESSENTIALS' 20 14 600 40 (New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)) | Out-Null
Add-Label "Version $Version" 22 54 600 22 $null $Grey | Out-Null
Add-Label ("Early test version: bugs, crashes and lost saves are possible. " +
    "Back up your saves first (the button below does it for you).") 22 82 600 44 $null $Yellow | Out-Null

Add-Label 'Undertale folder' 22 136 600 22 | Out-Null
$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(22, 160)
$txtFolder.Size = New-Object System.Drawing.Size(490, 26)
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
$txtLog.Location = New-Object System.Drawing.Point(22, 276)
$txtLog.Size = New-Object System.Drawing.Size(596, 196)
$txtLog.ReadOnly = $true
$txtLog.BackColor = $Panel
$txtLog.ForeColor = [System.Drawing.Color]::White
$txtLog.BorderStyle = 'None'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$form.Controls.Add($txtLog)

Add-Label 'Undertale Essentials is free software (GNU GPL v3). Undertale belongs to Toby Fox; this is a fan-made mod.' 22 482 600 30 (New-Object System.Drawing.Font('Segoe UI', 8.5)) $Grey | Out-Null

# install.ps1's messages go to the log, in its colours
$script:Log = {
    param($text, $color)
    $c = switch ($color) {
        'Red' { [System.Drawing.Color]::FromArgb(255, 110, 110) }
        'Green' { [System.Drawing.Color]::FromArgb(110, 230, 110) }
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

function Update-Status {
    $dir = $txtFolder.Text.Trim().Trim('"')
    $hasGame = ($dir -ne '') -and (Test-Path -LiteralPath (Join-Path $dir 'UNDERTALE.exe'))
    $installed = $hasGame -and (Test-Installed $dir)
    if (-not $hasGame) {
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 110, 110)
        $lblStatus.Text = if ($dir -eq '') { 'Choose your Undertale folder (Browse...).' } else { "UNDERTALE.exe isn't in this folder." }
    } elseif ($installed) {
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(110, 230, 110)
        $lblStatus.Text = 'Undertale Essentials is installed in this folder.'
    } else {
        $lblStatus.ForeColor = [System.Drawing.Color]::White
        $lblStatus.Text = 'Undertale found. Undertale Essentials is not installed here yet.'
    }
    if ($hasGame -and -not $script:IconSet) {
        # the window gets Undertale's own icon
        try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $dir 'UNDERTALE.exe')); $script:IconSet = $true } catch {}
    }
    $btnInstall.Text = if ($installed) { 'Reinstall' } else { 'Install' }
    $btnInstall.Enabled = $hasGame
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
function Run-Safely([scriptblock]$action) {
    Set-Busy $true
    try { & $action } catch { Say "Something went wrong: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false }
}

$txtFolder.Add_TextChanged({ Update-Status })

$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Choose your Undertale folder (the one with UNDERTALE.exe). In Steam: right-click Undertale > Manage > Browse local files.'
    if ($txtFolder.Text -ne '' -and (Test-Path -LiteralPath $txtFolder.Text)) { $d.SelectedPath = $txtFolder.Text }
    if ($d.ShowDialog($form) -eq 'OK') { $txtFolder.Text = $d.SelectedPath }
})

$btnInstall.Add_Click({
    Run-Safely {
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
    if ($answer -ne 'Yes') { return }
    Run-Safely {
        $txtLog.Clear()
        Uninstall-Mod $txtFolder.Text.Trim().Trim('"') | Out-Null
    }
})

$btnBackup.Add_Click({
    Run-Safely {
        $txtLog.Clear()
        if (-not (Test-Path -LiteralPath $SaveDir)) {
            Say "No Undertale saves found yet (looked in $SaveDir)." 'Yellow'
            return
        }
        $dest = Join-Path $BackupRoot ('UNDERTALE ' + (Get-Date -Format 'yyyy-MM-dd HH.mm.ss'))
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
        Copy-Item -LiteralPath $SaveDir -Destination $dest -Recurse
        Say 'Saves backed up to:' 'Green'
        Say "  $dest" 'White'
        Say 'To restore them, copy the files from there back into:' 'Gray'
        Say "  $SaveDir" 'Gray'
        Start-Process explorer.exe -ArgumentList "`"$dest`""
    }
})

$btnPlay.Add_Click({
    Run-Safely {
        if (-not (Get-Process steam -ErrorAction SilentlyContinue)) {
            Say 'Steam is not running. Start Steam first, then click Play again.' 'Yellow'
            return
        }
        $dir = $txtFolder.Text.Trim().Trim('"')
        Start-Process -FilePath (Join-Path $dir 'UNDERTALE.exe') -ArgumentList "-game $ModFile" -WorkingDirectory $dir
        Say 'Starting Undertale with Undertale Essentials...' 'Green'
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
    Show-Fatal "The installer stopped because of an error:`n`n$($_.Exception.Message)"
}
