<#
.SYNOPSIS
  Creates a "smoke pack" snapshot you can share: repo tree + key file contents + module export lists + environment info.

.DESCRIPTION
  - Works on Windows PowerShell 5.1 and PowerShell 7+
  - Avoids common secret-ish filenames (token/secret/password/etc)
  - Excludes heavy folders (.git, node_modules, bin/obj, venv, dist/build, etc)
  - Produces:
      .smokepack\<timestamp>\Snapshot.md
      .smokepack\<timestamp>\tree.txt
      .smokepack\<timestamp>\env.json
      .smokepack\<timestamp>\modules.json
    And optionally:
      .smokepack\SmokePack_<repo>_<timestamp>.zip

.EXAMPLE
  # From repo root:
  .\QuickSmokePack.ps1 -RepoRoot . -Zip

.EXAMPLE
  # Explicit module manifest to attempt import + export capture:
  .\QuickSmokePack.ps1 -RepoRoot . -ModuleManifest ".\src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1" -Zip
#>

[CmdletBinding()]
param(
    # Root of the repo to snapshot
    [Parameter()]
    [string]$RepoRoot = (Get-Location).Path,

    # Optional: module manifest (.psd1) to try importing and listing exported commands
    [Parameter()]
    [string]$ModuleManifest,

    # Where to write output (default: <RepoRoot>\.smokepack)
    [Parameter()]
    [string]$OutDir,

    # Create a zip file of the snapshot folder
    [Parameter()]
    [switch]$Zip,

    # Max file size (KB) to embed into Snapshot.md
    [Parameter()]
    [ValidateRange(1, 10240)]
    [int]$MaxEmbedFileKB = 256,

    # Hard cap to avoid runaway snapshot sizes
    [Parameter()]
    [ValidateRange(10, 5000)]
    [int]$MaxFiles = 800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    # Using .NET keeps this PS 5.1+ compatible and avoids Split-Path edge-cases
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-ExcludePath {
    param(
        [Parameter(Mandatory)][string]$FullName,
        [Parameter(Mandatory)][string]$RepoRootFull
    )

    # Build a repo-relative view of the path so we can exclude folders anywhere in the tree
    $rel = $FullName.Substring($RepoRootFull.Length).TrimStart('\', '/')
    $parts = $rel -split '[\\/]' | Where-Object { $_ -ne '' }

    # Exclude common heavy/noisy directories anywhere in the path
    $excludeDirs = @(
        '.git', 'node_modules', 'bin', 'obj', 'dist', 'build', '.next', 'coverage',
        '.venv', 'venv', '.pytest_cache', '__pycache__', '.idea', '.vs'
    )

    foreach ($p in $parts) {
        foreach ($d in $excludeDirs) {
            if ($p -ieq $d) { return $true }
        }
    }

    # Exclude secret-ish filenames (best-effort)
    $name = [System.IO.Path]::GetFileName($FullName)
    $secretNamePatterns = @(
        '(?i)secret', '(?i)token', '(?i)apikey', '(?i)clientsecret', '(?i)password',
        '(?i)\.pfx$', '(?i)\.p12$', '(?i)\.pem$', '(?i)id_rsa', '(?i)\.kdbx$'
    )
    foreach ($rx in $secretNamePatterns) {
        if ($name -match $rx) { return $true }
    }

    return $false
}

function Get-RepoFiles {
    param([Parameter(Mandatory)][string]$RepoRootFull)

    # Keep it mostly "code + config + docs"
    $includeExt = @(
        '.ps1', '.psm1', '.psd1', '.ps1xml',
        '.json', '.yml', '.yaml',
        '.md', '.txt', '.log',
        '.js', '.ts', '.tsx', '.html', '.css',
        '.cs', '.csproj', '.sln'
    )

    $all = Get-ChildItem -LiteralPath $RepoRootFull -Recurse -Force -File |
        Where-Object {
            ($includeExt -contains $_.Extension) -and (-not (Test-ExcludePath -FullName $_.FullName -RepoRootFull $RepoRootFull))
        } |
        Sort-Object FullName

    if ($all.Count -gt $MaxFiles) {
        $all = $all | Select-Object -First $MaxFiles
    }

    return $all
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string]$Path
    )
    $json = $Object | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
}

# -----------------------------
# Resolve + prep output folder
# -----------------------------
$repoRootFull = Resolve-FullPath -Path $RepoRoot
if (-not (Test-Path -LiteralPath $repoRootFull)) {
    throw ('RepoRoot not found: {0}' -f $repoRootFull)
}

if (-not $OutDir) {
    $OutDir = Join-Path -Path $repoRootFull -ChildPath '.smokepack'
}
$outDirFull = Resolve-FullPath -Path $OutDir

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$repoName = [System.IO.Path]::GetFileName($repoRootFull.TrimEnd('\', '/'))

$stageDir = Join-Path -Path $outDirFull -ChildPath $timestamp
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

$treePath = Join-Path -Path $stageDir -ChildPath 'tree.txt'
$snapPath = Join-Path -Path $stageDir -ChildPath 'Snapshot.md'
$envPath = Join-Path -Path $stageDir -ChildPath 'env.json'
$modulesPath = Join-Path -Path $stageDir -ChildPath 'modules.json'

Write-Host ('RepoRoot : {0}' -f $repoRootFull)
Write-Host ('StageDir : {0}' -f $stageDir)

# -----------------------------
# Collect file list + tree
# -----------------------------
$files = Get-RepoFiles -RepoRootFull $repoRootFull

$relPaths = $files | ForEach-Object {
    $_.FullName.Substring($repoRootFull.Length).TrimStart('\', '/')
}

# Tree is just a relative file list (fast + reliable)
[System.IO.File]::WriteAllLines($treePath, $relPaths, [System.Text.Encoding]::UTF8)

# -----------------------------
# Environment info
# -----------------------------
$envObj = [ordered]@{
    Timestamp   = (Get-Date).ToString('o')
    RepoName    = $repoName
    RepoRoot    = $repoRootFull
    User        = [Environment]::UserName
    MachineName = [Environment]::MachineName
    OS          = [Environment]::OSVersion.VersionString
    PSVersion   = $PSVersionTable.PSVersion.ToString()
    PSEdition   = $PSVersionTable.PSEdition
    CLRVersion  = $PSVersionTable.CLRVersion.ToString()
    CurrentDir  = (Get-Location).Path
}
Write-JsonFile -Object $envObj -Path $envPath

# -----------------------------
# Module import/export info (best-effort)
# -----------------------------
$modulesObj = [ordered]@{
    AttemptedManifest = $null
    ImportSucceeded   = $false
    ImportError       = $null
    ModuleInfo        = $null
    ExportedCommands  = @()
}

if ($ModuleManifest) {

    # If user passed a relative path, anchor it to the repo root.
    $mmCandidate = if ([System.IO.Path]::IsPathRooted($ModuleManifest)) {
        $ModuleManifest
    }
    else {
        Join-Path -Path $repoRootFull -ChildPath $ModuleManifest
    }

    $mmFull = Resolve-FullPath -Path $mmCandidate

    if (Test-Path -LiteralPath $mmFull) {
        $modulesObj.AttemptedManifest = $mmFull

        try {
            Import-Module -LiteralPath $mmFull -Force -ErrorAction Stop

            # Grab the module instance that was loaded from this manifest path
            $m = Get-Module | Where-Object { $_.Path -eq $mmFull } | Select-Object -First 1

            $modulesObj.ImportSucceeded = $true
            $modulesObj.ModuleInfo = [ordered]@{
                Name    = $m.Name
                Version = $m.Version.ToString()
                Path    = $m.Path
            }

            $cmds = Get-Command -Module $m.Name -ErrorAction SilentlyContinue |
                Sort-Object Name |
                Select-Object Name, CommandType, Source

            $modulesObj.ExportedCommands = $cmds
        }
        catch {
            $modulesObj.ImportError = $_.Exception.Message
        }
    }
    else {
        $modulesObj.ImportError = ('ModuleManifest not found: {0}' -f $mmFull)
    }
}

Write-JsonFile -Object $modulesObj -Path $modulesPath

# -----------------------------
# Snapshot.md (tree + file contents)
# -----------------------------
$sb = New-Object System.Text.StringBuilder

# NOTE: Avoid Markdown backticks inside *double-quoted* PowerShell strings.
#       In PS, the backtick is an escape char in "..." and can break parsing.
[void]$sb.AppendLine('# SmokePack Snapshot')
[void]$sb.AppendLine()
[void]$sb.AppendLine(('- **Repo:** {0}' -f $repoName))
[void]$sb.AppendLine(('- **Timestamp:** {0}' -f (Get-Date).ToString('o')))
[void]$sb.AppendLine(('- **RepoRoot:** `{0}`' -f $repoRootFull))
[void]$sb.AppendLine(('- **PSVersion:** {0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition))
[void]$sb.AppendLine()

[void]$sb.AppendLine('## Tree (relative file list)')
[void]$sb.AppendLine()
[void]$sb.AppendLine('```text')
foreach ($p in $relPaths) { [void]$sb.AppendLine($p) }
[void]$sb.AppendLine('```')
[void]$sb.AppendLine()

[void]$sb.AppendLine(('## Embedded files (<= {0} KB)' -f $MaxEmbedFileKB))
[void]$sb.AppendLine()

foreach ($f in $files) {

    $sizeKB = [Math]::Round($f.Length / 1KB, 2)
    if ($sizeKB -gt $MaxEmbedFileKB) { continue }

    $rel = $f.FullName.Substring($repoRootFull.Length).TrimStart('\', '/')
    $ext = $f.Extension.ToLowerInvariant()

    # Pick a decent fence language hint for Markdown renderers
    $lang = switch ($ext) {
        '.ps1' { 'powershell' }
        '.psm1' { 'powershell' }
        '.psd1' { 'powershell' }
        '.ps1xml' { 'xml' }
        '.json' { 'json' }
        '.yml' { 'yaml' }
        '.yaml' { 'yaml' }
        '.md' { 'markdown' }
        '.html' { 'html' }
        '.css' { 'css' }
        '.js' { 'javascript' }
        '.ts' { 'typescript' }
        '.tsx' { 'tsx' }
        default { '' }
    }

    [void]$sb.AppendLine(('### {0}  (`{1} KB`)' -f $rel, $sizeKB))
    [void]$sb.AppendLine()

    if ([string]::IsNullOrWhiteSpace($lang)) {
        [void]$sb.AppendLine('```')
    }
    else {
        [void]$sb.AppendLine(('```{0}' -f $lang))
    }

    $content = $null

    try {
        # Try UTF-8 first (most repos)
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    }
    catch {
        try {
            # Fallback: let PS decide encoding
            $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
        }
        catch {
            $content = ('<<FAILED TO READ FILE CONTENT: {0}>>' -f $_.Exception.Message)
        }
    }

    [void]$sb.AppendLine($content)
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine()
}

[System.IO.File]::WriteAllText($snapPath, $sb.ToString(), [System.Text.Encoding]::UTF8)

# -----------------------------
# Zip (optional)
# -----------------------------
if ($Zip) {
    $zipName = ('SmokePack_{0}_{1}.zip' -f $repoName, $timestamp)
    $zipPath = Join-Path -Path $outDirFull -ChildPath $zipName

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path -Path $stageDir -ChildPath '*') -DestinationPath $zipPath -Force
    Write-Host ('ZIP : {0}' -f $zipPath)
}

Write-Host ('DONE : {0}' -f $stageDir)
