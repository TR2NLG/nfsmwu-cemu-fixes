<#
.SYNOPSIS
Removes the shader cache entry that makes Cemu 2.6 crash while loading the shader cache of
Need for Speed Most Wanted U ("Compiling shaders", Exception 0x80000003 at Cemu.exe+0x48994e).

.DESCRIPTION
The crash is caused by one vertex shader (base hash b95e9a31ea76e5f5) in
shaderCache\transferable\<titleId>_shaders.bin. The script marks that entry as free and leaves all other
entries untouched. Before it changes a file it writes a backup copy next to it.
Cemu must be closed. The entry can come back when the game uses the shader again, so the script can simply
be run before every start (see Start-Cemu-With-Repair.cmd).

.PARAMETER CachePath
Full path of a <titleId>_shaders.bin file. Without it the script looks in %APPDATA%\Cemu and, for a
portable Cemu, in the folder the script is in.

.PARAMETER Hashes
Base hashes of the shaders to remove, as shown in Cemu's shader dump and in RenderDoc.

.PARAMETER ReportOnly
Only report what would be removed.
#>
param(
    [string]$CachePath = '',
    [string[]]$Hashes = @('b95e9a31ea76e5f5'),
    [switch]$ReportOnly
)
$ErrorActionPreference = 'Stop'
$titleIds = '0005000010128400', '0005000010128800', '000500001012b700'

$files = @()
if ($CachePath) { $files = @($CachePath) }
else {
    $roots = @()
    if ($env:APPDATA) { $roots += (Join-Path $env:APPDATA 'Cemu') }
    $roots += $PSScriptRoot
    foreach ($r in $roots) { foreach ($t in $titleIds) { $f = Join-Path $r "shaderCache\transferable\${t}_shaders.bin"; if (Test-Path $f) { $files += $f } } }
}
if (-not $files.Count) { 'No shader cache of Need for Speed Most Wanted U found. Pass the file with -CachePath.'; return }

# In the file table Cemu replaces the top three bits of the base hash with the shader type.
$mask = [Convert]::ToUInt64('1fffffffffffffff', 16)
foreach ($file in $files) {
    if (-not (Test-Path $file)) { "Not found: $file"; continue }
    $b = [IO.File]::ReadAllBytes($file)
    if ($b.Length -lt 128 -or $b[0] -ne 0x96 -or $b[1] -ne 0xb6 -or $b[2] -ne 0x71 -or $b[3] -ne 0x83) { "Unknown file format, nothing changed: $file"; continue }
    $data = [long][BitConverter]::ToUInt64($b, 8)
    $table = $data + [long][BitConverter]::ToUInt64($b, 16)
    $count = [int]([BitConverter]::ToUInt32($b, 24) / 32)
    if ($table -lt 0 -or $table + [long]$count * 32 -gt $b.Length) { "File table lies outside the file, nothing changed: $file"; continue }
    $removed = 0
    foreach ($h in $Hashes) {
        $want = [Convert]::ToUInt64($h, 16)
        for ($i = 0; $i -lt $count; $i++) {
            $o = [int]($table + $i * 32)
            $name1 = [BitConverter]::ToUInt64($b, $o); $name2 = [BitConverter]::ToUInt64($b, $o + 8)
            if ($name1 -eq 0 -and $name2 -eq 0) { continue }
            if (($name1 -band $mask) -ne ($want -band $mask)) { continue }
            # The entry itself starts with a version byte followed by the full base hash (big endian). Compare it to be sure.
            $off = $data + [long][BitConverter]::ToUInt64($b, $o + 16)
            if ($off -lt 0 -or $off + 9 -gt $b.Length) { continue }
            $full = [uint64]0; for ($k = 1; $k -le 8; $k++) { $full = ($full -shl 8) -bor [uint64]$b[$off + $k] }
            if ($full -ne $want) { continue }
            if ($ReportOnly) { "Would remove $h (slot $i) from $file" }
            else { for ($k = 0; $k -lt 32; $k++) { $b[$o + $k] = 0 }; "Removed $h (slot $i)." }
            $removed++
        }
    }
    if ($removed -eq 0) { "Nothing to do: $file"; continue }
    if ($ReportOnly) { continue }
    # The file must not be open in Cemu.
    try { $lock = [IO.File]::Open($file, 'Open', 'ReadWrite', 'None'); $lock.Dispose() }
    catch { "The cache file is in use, close Cemu first. Nothing changed: $file"; continue }
    $backup = $file + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $file $backup
    [IO.File]::WriteAllBytes($file, $b)
    "Done. Backup of the old file: $backup"
}
