# Duplicate Download Deleter - Background Worker
# Watches Downloads folder, keeps newest Chrome-style duplicate, deletes older copies.
$ErrorActionPreference = 'SilentlyContinue'

$downloadFolder = [Environment]::GetFolderPath('UserProfile') + "\Downloads"
$logFile = Join-Path $PSScriptRoot "cleaner.log"

function Get-DuplicateKey {
    param([string]$Name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $ext  = [System.IO.Path]::GetExtension($Name)
    $base = $base -replace ' \(\d+\)$', ''
    return ($base + $ext).ToLowerInvariant()
}

function Clean-Duplicates {
    if (!(Test-Path -LiteralPath $downloadFolder)) { return }

    $files = Get-ChildItem -LiteralPath $downloadFolder -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -ne '.crdownload' }

    $groups = $files | Group-Object { Get-DuplicateKey $_.Name }

    foreach ($group in $groups) {
        if ($group.Count -le 1) { continue }

        $sorted = $group.Group | Sort-Object LastWriteTime -Descending
        $keep   = $sorted | Select-Object -First 1

        $sorted | Select-Object -Skip 1 | ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                "$(Get-Date -Format s) Deleted: $($_.Name) | Kept newest: $($keep.Name)" |
                    Add-Content -LiteralPath $logFile
            } catch {}
        }
    }
}

# Initial clean
Clean-Duplicates

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $downloadFolder
$watcher.Filter = '*.*'
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, CreationTime'
$watcher.EnableRaisingEvents = $true

$action = {
    Start-Sleep -Seconds 4
    Clean-Duplicates
}

$null = Register-ObjectEvent $watcher Created -Action $action
$null = Register-ObjectEvent $watcher Renamed -Action $action

while ($true) {
    Start-Sleep -Seconds 10
    Clean-Duplicates
}
