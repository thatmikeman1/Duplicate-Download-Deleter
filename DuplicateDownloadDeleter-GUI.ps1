# Duplicate Download Deleter - GUI
# Requires Windows PowerShell (WinForms)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir   = $PSScriptRoot
$workerPs1   = Join-Path $scriptDir "DuplicateDownloadDeleter.ps1"
$vbsPath     = Join-Path $scriptDir "Run Silently.vbs"
$logFile     = Join-Path $scriptDir "cleaner.log"
$startupName = "DuplicateDownloadDeleter"
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) "$startupName.lnk"

function Test-CleanerRunning {
    $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*DuplicateDownloadDeleter.ps1*' }
    return [bool]$procs
}

function Start-CleanerSilent {
    if (Test-CleanerRunning) { return $true }
    if (-not (Test-Path -LiteralPath $vbsPath)) {
        [System.Windows.Forms.MessageBox]::Show("Run Silently.vbs not found.", "Error", "OK", "Error") | Out-Null
        return $false
    }
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden
    Start-Sleep -Milliseconds 800
    return (Test-CleanerRunning)
}

function Stop-Cleaner {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*DuplicateDownloadDeleter.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 400
}

function Test-StartupEnabled {
    return (Test-Path -LiteralPath $startupLink)
}

function Enable-Startup {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startupLink)
    $shortcut.TargetPath = "wscript.exe"
    $shortcut.Arguments  = "`"$vbsPath`""
    $shortcut.WorkingDirectory = $scriptDir
    $shortcut.WindowStyle = 7   # Minimized / hidden style for the launcher
    $shortcut.Description = "Duplicate Download Deleter (silent)"
    $shortcut.Save()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
}

function Disable-Startup {
    if (Test-Path -LiteralPath $startupLink) {
        Remove-Item -LiteralPath $startupLink -Force -ErrorAction SilentlyContinue
    }
}

# ---------- Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Duplicate Download Deleter"
$form.Size = New-Object System.Drawing.Size(460, 420)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Status group
$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = "Status"
$grpStatus.Location = New-Object System.Drawing.Point(12, 12)
$grpStatus.Size = New-Object System.Drawing.Size(420, 70)
$form.Controls.Add($grpStatus)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 28)
$lblStatus.Size = New-Object System.Drawing.Size(390, 25)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$grpStatus.Controls.Add($lblStatus)

# Actions group
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = "Actions"
$grpActions.Location = New-Object System.Drawing.Point(12, 95)
$grpActions.Size = New-Object System.Drawing.Size(420, 100)
$form.Controls.Add($grpActions)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Silently"
$btnStart.Location = New-Object System.Drawing.Point(20, 30)
$btnStart.Size = New-Object System.Drawing.Size(120, 40)
$btnStart.FlatStyle = "System"
$grpActions.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop Cleaner"
$btnStop.Location = New-Object System.Drawing.Point(155, 30)
$btnStop.Size = New-Object System.Drawing.Size(120, 40)
$btnStop.FlatStyle = "System"
$grpActions.Controls.Add($btnStop)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh Status"
$btnRefresh.Location = New-Object System.Drawing.Point(290, 30)
$btnRefresh.Size = New-Object System.Drawing.Size(110, 40)
$btnRefresh.FlatStyle = "System"
$grpActions.Controls.Add($btnRefresh)

# Startup group
$grpStartup = New-Object System.Windows.Forms.GroupBox
$grpStartup.Text = "Run at Windows Startup (silent)"
$grpStartup.Location = New-Object System.Drawing.Point(12, 205)
$grpStartup.Size = New-Object System.Drawing.Size(420, 70)
$form.Controls.Add($grpStartup)

$chkStartup = New-Object System.Windows.Forms.CheckBox
$chkStartup.Text = "Add to Startup (runs completely silently when Windows starts)"
$chkStartup.Location = New-Object System.Drawing.Point(20, 28)
$chkStartup.Size = New-Object System.Drawing.Size(380, 25)
$chkStartup.AutoSize = $false
$grpStartup.Controls.Add($chkStartup)

# Log / info
$grpInfo = New-Object System.Windows.Forms.GroupBox
$grpInfo.Text = "Info & Log"
$grpInfo.Location = New-Object System.Drawing.Point(12, 285)
$grpInfo.Size = New-Object System.Drawing.Size(420, 85)
$form.Controls.Add($grpInfo)

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(15, 22)
$lblInfo.Size = New-Object System.Drawing.Size(390, 50)
$lblInfo.Text = "Watches your Downloads folder.`nKeeps the newest file, deletes older Chrome-style duplicates (file (1).zip etc).`nActivity is written to cleaner.log"
$grpInfo.Controls.Add($lblInfo)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = "Open Log"
$btnOpenLog.Location = New-Object System.Drawing.Point(320, 50)
$btnOpenLog.Size = New-Object System.Drawing.Size(80, 25)
$btnOpenLog.FlatStyle = "System"
$grpInfo.Controls.Add($btnOpenLog)

# ---------- Logic ----------
function Update-UI {
    $running = Test-CleanerRunning
    if ($running) {
        $lblStatus.Text = "● Running (silent background)"
        $lblStatus.ForeColor = [System.Drawing.Color]::ForestGreen
        $btnStart.Enabled = $false
        $btnStop.Enabled  = $true
    } else {
        $lblStatus.Text = "○ Stopped"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
        $btnStart.Enabled = $true
        $btnStop.Enabled  = $false
    }

    $chkStartup.Checked = Test-StartupEnabled
}

$btnStart.Add_Click({
    $btnStart.Enabled = $false
    if (Start-CleanerSilent) {
        [System.Windows.Forms.MessageBox]::Show("Cleaner started silently in the background.`nNo PowerShell window will stay open.", "Started", "OK", "Information") | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show("Failed to start the cleaner. Check that the .ps1 and .vbs files are present.", "Error", "OK", "Error") | Out-Null
    }
    Update-UI
})

$btnStop.Add_Click({
    Stop-Cleaner
    Update-UI
    [System.Windows.Forms.MessageBox]::Show("Cleaner stopped.", "Stopped", "OK", "Information") | Out-Null
})

$btnRefresh.Add_Click({ Update-UI })

$chkStartup.Add_CheckedChanged({
    if ($chkStartup.Checked) {
        if (-not (Test-Path -LiteralPath $vbsPath)) {
            [System.Windows.Forms.MessageBox]::Show("Run Silently.vbs not found.", "Error", "OK", "Error") | Out-Null
            $chkStartup.Checked = $false
            return
        }
        Enable-Startup
    } else {
        Disable-Startup
    }
})

$btnOpenLog.Add_Click({
    if (Test-Path -LiteralPath $logFile) {
        Start-Process notepad.exe -ArgumentList "`"$logFile`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("No log file yet. The cleaner creates cleaner.log when it deletes something.", "No log", "OK", "Information") | Out-Null
    }
})

$form.Add_Shown({ Update-UI })
$form.Add_FormClosing({
    # Leave the background cleaner running if the user closes the GUI
})

# Auto-refresh status every 3 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({ Update-UI })
$timer.Start()

[void]$form.ShowDialog()
$timer.Stop()
