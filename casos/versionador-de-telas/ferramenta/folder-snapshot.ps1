<#
.SYNOPSIS
    Keeps numbered snapshots of working files inside per-file archive folders.

.DESCRIPTION
    You keep a set of "live" files in a container folder and overwrite them as you
    work. Each live file has a matching subfolder, named after it. This script
    copies each live file into its subfolder as the next numbered version, and
    normalizes the names of every version already stored there.

    Layout:

        container/
            report.png              <- live file, overwritten as you work
            chart.png               <- live file
            report/                 <- archive folder, named after the live file
                report-1.png
                report-2.png
            chart/
                chart-1.png

    Because names are derived from the folder, renaming a folder and re-running
    renames its stored versions to match. A live file whose content is identical
    to the newest stored version is skipped, so re-running costs nothing.

.PARAMETER Path
    Folder to work on. Defaults to the current directory.

.PARAMETER All
    Treat Path as the container and process every subfolder in it.
    Without this switch, Path is a single archive folder and its parent is
    used as the container.

.PARAMETER Suffix
    Text appended to the folder name when building file names, e.g. "draft"
    produces "report-draft-1.png". If omitted, the script asks once.
    Pass an empty string to skip the prompt and use no suffix.

.PARAMETER Yes
    Skip the confirmation prompt.

.EXAMPLE
    .\folder-snapshot.ps1 -Path .\container -All

.EXAMPLE
    .\folder-snapshot.ps1 -Path .\container\report -Suffix draft -Yes
#>

[CmdletBinding()]
param(
    [string]$Path = ".",
    [switch]$All,
    [string]$Suffix,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# File types treated as content. Anything else (.bat, .ps1, .txt) is ignored.
$extensions = @('.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg', '.pdf')

$root = Get-Item -LiteralPath $Path

if ($All) {
    $container = $root
    $targets = @(Get-ChildItem -LiteralPath $root.FullName -Directory)
    if ($targets.Count -eq 0) {
        Write-Host "No subfolders found in $($root.FullName)."
        exit 0
    }
}
else {
    $container = $root.Parent
    $targets = @($root)
}

# --- Suffix, asked once ---
if (-not $PSBoundParameters.ContainsKey('Suffix')) {
    Write-Host ""
    Write-Host "Container : $($container.FullName)"
    Write-Host "Folders   : $($targets.Count)"
    Write-Host ""
    $Suffix = Read-Host "Append anything to the file names? (leave empty for none)"
}

$Suffix = $Suffix.Trim()
if ($Suffix -and $Suffix -notmatch '^[-_]') { $Suffix = "-$Suffix" }

# --- Helpers ---

# Candidate folder names a live file could belong to, most specific first.
function Get-Candidates([string]$baseName, [string]$sfx) {
    $names = @()
    $n = $baseName.Trim()
    $names += $n

    # Strip a trailing copy marker like " (2)".
    $n = ($n -replace '\s*\(\d+\)\s*$', '').Trim()
    if ($names -notcontains $n) { $names += $n }

    # Strip the suffix, with or without a version number.
    if ($sfx) {
        $esc = [regex]::Escape($sfx)
        $n = ($n -replace "$esc(-\d+)?$", '').Trim()
        if ($names -notcontains $n) { $names += $n }
    }
    return $names
}

# --- Build the plan ---
$plan = @()
$skipped = @()
$claimed = @{}

foreach ($folder in $targets) {
    $base = "$($folder.Name)$Suffix"

    $stored = @()
    $loose = @()

    foreach ($f in (Get-ChildItem -LiteralPath $folder.FullName -File |
                    Where-Object { $extensions -contains $_.Extension.ToLower() })) {
        if ($f.BaseName -match '^(?<prefix>.+)-(?<num>\d+)$') {
            $stored += [pscustomobject]@{ File = $f; Num = [int]$Matches['num'] }
        }
        else {
            $loose += $f
        }
    }

    $highest = 0
    $newest = $null
    if ($stored.Count -gt 0) {
        $highest = ($stored | Measure-Object -Property Num -Maximum).Maximum
        $newest = ($stored | Sort-Object Num | Select-Object -Last 1).File
    }

    # Live files in the container that belong to this folder.
    $incoming = @()
    foreach ($f in (Get-ChildItem -LiteralPath $container.FullName -File |
                    Where-Object { $extensions -contains $_.Extension.ToLower() })) {

        if ((Get-Candidates $f.BaseName $Suffix) -notcontains $folder.Name) { continue }
        $claimed[$f.FullName] = $true

        if ($newest) {
            $a = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
            $b = (Get-FileHash -LiteralPath $newest.FullName -Algorithm SHA256).Hash
            if ($a -eq $b) {
                $skipped += [pscustomobject]@{ Folder = $folder.Name; Name = $f.Name; Num = $highest }
                continue
            }
        }
        $incoming += $f
    }

    # Existing versions keep their number, only the prefix is normalized.
    foreach ($s in ($stored | Sort-Object Num)) {
        $plan += [pscustomobject]@{
            Folder = $folder
            From   = $s.File.Name
            To     = "$base-$($s.Num)$($s.File.Extension.ToLower())"
            Item   = $s.File
            Action = 'RENAME'
        }
    }

    $i = $highest

    # Stray files already inside the folder join the sequence in place.
    foreach ($f in ($loose | Sort-Object LastWriteTime, Name)) {
        $i++
        $plan += [pscustomobject]@{
            Folder = $folder
            From   = $f.Name
            To     = "$base-$i$($f.Extension.ToLower())"
            Item   = $f
            Action = 'RENAME'
        }
    }

    # Live files become new copies; the original stays in the container.
    foreach ($f in ($incoming | Sort-Object LastWriteTime, Name)) {
        $i++
        $plan += [pscustomobject]@{
            Folder = $folder
            From   = $f.Name
            To     = "$base-$i$($f.Extension.ToLower())"
            Item   = $f
            Action = 'COPY'
        }
    }
}

# --- Safety check: two files landing on the same name ---
$clashes = $plan | Group-Object { "$($_.Folder.FullName)|$($_.To)" } | Where-Object { $_.Count -gt 1 }
if ($clashes) {
    Write-Host ""
    Write-Host "ABORTED. Two or more files would end up with the same name:" -ForegroundColor Red
    foreach ($c in $clashes) {
        Write-Host "  $(($c.Name -split '\|')[1])  in  $(($c.Name -split '\|')[0])"
        foreach ($item in $c.Group) { Write-Host "     <- $($item.From)" }
    }
    Write-Host ""
    Write-Host "Nothing was changed."
    exit 1
}

$changes = $plan | Where-Object { $_.Action -eq 'COPY' -or ($_.From -cne $_.To) }

$unmatched = @(Get-ChildItem -LiteralPath $container.FullName -File |
    Where-Object { $extensions -contains $_.Extension.ToLower() -and -not $claimed[$_.FullName] })

# --- Show the plan ---
Write-Host ""
if ($changes.Count -eq 0) {
    Write-Host "Nothing to do. $($plan.Count) stored version(s), all named correctly."
}
else {
    $copies = @($changes | Where-Object { $_.Action -eq 'COPY' }).Count
    Write-Host "Planned: $copies new cop(y/ies), $($changes.Count - $copies) rename(s)."
    Write-Host ""
    foreach ($g in ($changes | Group-Object { $_.Folder.Name })) {
        Write-Host "  [$($g.Name)]"
        foreach ($m in $g.Group) {
            if ($m.Action -eq 'COPY') { Write-Host "    ..\$($m.From)   [COPY]" -ForegroundColor Cyan }
            else { Write-Host "    $($m.From)" }
            Write-Host "       -> $($m.To)"
        }
    }
}

foreach ($s in $skipped) {
    Write-Host ""
    Write-Host "  [$($s.Folder)] $($s.Name) is identical to version $($s.Num). No new copy."
}

if ($unmatched.Count -gt 0 -and $All) {
    Write-Host ""
    Write-Host "  $($unmatched.Count) file(s) in the container match no folder: $(($unmatched | ForEach-Object { $_.Name }) -join ', ')"
}

if ($changes.Count -eq 0) { exit 0 }

Write-Host ""
if (-not $Yes) {
    $answer = Read-Host "Proceed? (Y/N)"
    if ($answer -notmatch '^[yYsS]') {
        Write-Host "Cancelled. Nothing was changed."
        exit 0
    }
}

# --- Execute, in two passes through a temporary name ---
$staged = @()
foreach ($m in $changes) {
    $tmp = "__tmp__" + [guid]::NewGuid().ToString('N').Substring(0, 8) + $m.Item.Extension
    $dest = Join-Path $m.Folder.FullName $tmp
    if ($m.Action -eq 'COPY') { Copy-Item -LiteralPath $m.Item.FullName -Destination $dest }
    else { Move-Item -LiteralPath $m.Item.FullName -Destination $dest }
    $staged += [pscustomobject]@{ Temp = $dest; Final = $m.To }
}

foreach ($s in $staged) {
    Rename-Item -LiteralPath $s.Temp -NewName $s.Final
}

$copies = @($changes | Where-Object { $_.Action -eq 'COPY' }).Count
Write-Host ""
Write-Host "Done. $copies copied, $($changes.Count - $copies) renamed." -ForegroundColor Green
