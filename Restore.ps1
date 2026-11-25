param([string]$BackupPath)
$ErrorActionPreference = 'Stop'
if (-not $BackupPath) { $BackupPath = Read-Host 'Paste the backup folder printed by Install.ps1' }
if (@(Get-Process GONEfishing* -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Close GONE Fishing first.' }
$backupRoot = [IO.Path]::GetFullPath($BackupPath.Trim().Trim('"')).TrimEnd('\')
$container = [IO.DirectoryInfo][IO.Path]::GetDirectoryName($backupRoot)
if ($container.Name -ine 'GFM-Coop-Backups') { throw 'Unexpected backup location.' }
$gameRoot = $container.Parent.FullName
if (-not [IO.File]::Exists((Join-Path $gameRoot 'GONEfishing-Win64-Shipping.exe'))) { throw 'Game root missing.' }
$record = Get-Content -LiteralPath (Join-Path $backupRoot 'record.json') -Raw | ConvertFrom-Json
if ($record.GameRoot -ine $gameRoot -or $record.Status -ne 'installed_verified') { throw 'Backup is not an installed record for this game folder.' }
function Join-Safe([string]$Root,[string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) { throw 'Absolute path rejected.' }
    $result = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $result.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes root.' }
    return $result
}
function Hash-File([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose(); $stream.Dispose() }
}
foreach ($entry in $record.Files) {
    $target = Join-Safe $gameRoot $entry.Relative
    if (-not [IO.File]::Exists($target) -or (Hash-File $target) -ne $entry.After) { throw ('Changed after installation; not overwriting: '+$entry.Relative) }
    if ($entry.Existed) {
        if ((Hash-File (Join-Safe $backupRoot ('files/'+$entry.Relative))) -ne $entry.Before) { throw 'Original backup hash mismatch.' }
    }
}
foreach ($entry in $record.Files) {
    $target = Join-Safe $gameRoot $entry.Relative
    if ($entry.Existed) { [IO.File]::Copy((Join-Safe $backupRoot ('files/'+$entry.Relative)),$target,$true) }
    else { Remove-Item -LiteralPath $target -Force }
}
$record.Status='restored'
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backupRoot 'record.json') -Encoding UTF8
Write-Host 'Restored original files. SaveGames were not changed.'
