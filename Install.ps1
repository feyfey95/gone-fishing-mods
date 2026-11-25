param([string]$GameWin64)
$ErrorActionPreference = 'Stop'
if (-not $GameWin64) { $GameWin64 = Read-Host 'Paste your GONEfishing Binaries\Win64 folder' }
$gameRoot = [IO.Path]::GetFullPath($GameWin64.Trim().Trim('"')).TrimEnd('\')
if (-not [IO.File]::Exists((Join-Path $gameRoot 'GONEfishing-Win64-Shipping.exe'))) { throw 'Wrong folder: game Shipping.exe not found.' }
if (@(Get-Process GONEfishing* -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Close GONE Fishing before installation.' }
function Join-Safe([string]$Root, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) { throw 'Absolute manifest path rejected.' }
    $result = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $result.StartsWith($Root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes target folder.' }
    return $result
}
function Hash-File([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Hash-Bytes([byte[]]$Data) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Data))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$payloadRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'payload'))
$ancestor = [IO.DirectoryInfo]$gameRoot
while ($ancestor -and $ancestor.Name -ine 'steamapps') { $ancestor = $ancestor.Parent }
if ($ancestor) {
    $appManifest = Join-Path $ancestor.FullName 'appmanifest_3645890.acf'
    if ([IO.File]::Exists($appManifest)) {
        $appText = [IO.File]::ReadAllText($appManifest)
        if ($appText -match '"buildid"\s+"(\d+)"') {
            if ($manifest.ExpectedSteamBuild -and $Matches[1] -ne $manifest.ExpectedSteamBuild) { throw 'Game build differs from tested build. No files changed.' }
        }
    }
}
$plan = @()
foreach ($file in $manifest.Files) {
    $source = Join-Safe $payloadRoot $file.Path
    $target = Join-Safe $gameRoot $file.Path
    if ((Hash-File $source) -ne $file.SHA256) { throw ('Package hash mismatch: ' + $file.Path) }
    if ([IO.File]::Exists($target)) {
        $beforeHash = Hash-File $target
        if ($manifest.ProtectedLoaders -contains $file.Path) {
            if ($beforeHash -ne $file.SHA256) { throw ('Different existing UE4SS loader; no replacement performed: ' + $file.Path) }
        }
        if ($beforeHash -eq $file.SHA256) { continue }
    } else { $beforeHash = $null }
    $plan += [PSCustomObject]@{Relative=$file.Path; Source=$source; Target=$target; Bytes=$null; Before=$beforeHash; After=$file.SHA256}
}
# Preserve other mods and their order; only enable this mod's entry.
$modsRelative = 'ue4ss/Mods/mods.txt'
$modsPath = Join-Safe $gameRoot $modsRelative
$modsText = if ([IO.File]::Exists($modsPath)) { [IO.File]::ReadAllText($modsPath) } else { '' }
$pattern = '(?m)^\s*GonFishMods\s*:\s*\d+\s*$'
if ([regex]::IsMatch($modsText,$pattern)) { $newModsText = [regex]::Replace($modsText,$pattern,'GonFishMods : 1') }
else { $newModsText = "GonFishMods : 1`r`n" + $modsText }
if ($newModsText -ne $modsText) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($newModsText)
    $before = if ([IO.File]::Exists($modsPath)) { Hash-File $modsPath } else { $null }
    $plan += [PSCustomObject]@{Relative=$modsRelative; Source=$null; Target=$modsPath; Bytes=$bytes; Before=$before; After=(Hash-Bytes $bytes)}
}
foreach ($item in $plan) {
    $check = $item.Target
    while ($check.Length -ge $gameRoot.Length) {
        if (Test-Path -LiteralPath $check) {
            if ((Get-Item -LiteralPath $check -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Junction/symlink destination requires manual review.' }
        }
        if ($check -ieq $gameRoot) { break }
        $check = [IO.Path]::GetDirectoryName($check)
    }
}
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backupRoot = Join-Safe $gameRoot ('GFM-Coop-Backups/' + $stamp)
[IO.Directory]::CreateDirectory($backupRoot) | Out-Null
$entries = @()
foreach ($item in $plan) {
    if ($item.Before) {
        $backupFile = Join-Safe $backupRoot ('files/' + $item.Relative)
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backupFile)) | Out-Null
        [IO.File]::Copy($item.Target,$backupFile,$false)
        if ((Hash-File $backupFile) -ne $item.Before) { throw 'Backup verification failed. Installation not started.' }
    }
    $entries += [PSCustomObject]@{Relative=$item.Relative; Existed=($null -ne $item.Before); Before=$item.Before; After=$item.After}
}
$record = [PSCustomObject]@{GameRoot=$gameRoot; Version=$manifest.Version; Status='backup_verified'; Files=$entries}
$recordPath = Join-Path $backupRoot 'record.json'
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
try {
    foreach ($item in $plan) {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Target)) | Out-Null
        if ($null -ne $item.Bytes) { [IO.File]::WriteAllBytes($item.Target,$item.Bytes) }
        else { [IO.File]::Copy($item.Source,$item.Target,$true) }
        if ((Hash-File $item.Target) -ne $item.After) { throw 'Installed hash mismatch.' }
    }
    $record.Status = 'installed_verified'
} catch {
    foreach ($entry in $entries) {
        $target = Join-Safe $gameRoot $entry.Relative
        if ($entry.Existed) { [IO.File]::Copy((Join-Safe $backupRoot ('files/' + $entry.Relative)),$target,$true) }
        elseif ([IO.File]::Exists($target)) { Remove-Item -LiteralPath $target -Force }
    }
    $record.Status = 'rolled_back'
    throw
} finally { $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8 }
Write-Host 'Installed and verified. Start the game normally; do not hot-reload UE4SS.'
Write-Host ('Backup for Restore.ps1: ' + $backupRoot)
