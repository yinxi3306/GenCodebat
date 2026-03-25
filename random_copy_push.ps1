#Requires -Version 5.1
param(
  [Parameter(Mandatory = $true)]
  [string] $SourceRoot
)

$ErrorActionPreference = 'Stop'

function Test-ExcludedPath {
  param([string] $FullPath, [string[]] $ExcludeNames)
  $parts = $FullPath.Split([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar), [StringSplitOptions]::RemoveEmptyEntries)
  foreach ($n in $ExcludeNames) {
    if ($parts -contains $n) { return $true }
  }
  return $false
}

function Read-AllLinesRobust {
  param([string] $Path)
  try {
    return [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false, $true))
  }
  catch {
    return [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::Default)
  }
}

function Test-TextLikeFile {
  param([string] $Path, [int] $MaxBytes = 65536)
  $len = (Get-Item -LiteralPath $Path).Length
  if ($len -eq 0) { return $false }
  if ($len -gt 2MB) { return $false }
  $fs = [System.IO.File]::OpenRead($Path)
  try {
    $buf = New-Object byte[] ([Math]::Min($len, $MaxBytes))
    [void]$fs.Read($buf, 0, $buf.Length)
  }
  finally {
    $fs.Dispose()
  }
  if ($buf -contains 0) { return $false }
  return $true
}

$excludeDirs = @('.git', 'node_modules', 'bin', 'obj', 'dist', 'build')
$allowedExt = @(
  '.cs', '.ts', '.tsx', '.js', '.jsx', '.py', '.java', '.go', '.rs', '.md', '.txt'
) | ForEach-Object { $_.ToLowerInvariant() }

$root = [IO.Path]::GetFullPath($SourceRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
  Write-Error "SourceRoot is not a directory: $root"
  exit 2
}

$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
Push-Location $repoRoot
try {
  $null = git rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Not a git repository: $repoRoot"
    exit 3
  }

  $remotes = git remote 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $remotes) {
    Write-Error "No git remotes configured. Add one with: git remote add origin <url>"
    exit 4
  }
  if ($remotes -notcontains 'origin') {
    Write-Error "Remote 'origin' is not configured. Available remotes: $($remotes -join ', ')"
    exit 4
  }

  $candidates = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $allowedExt -contains $_.Extension.ToLowerInvariant() -and
        -not (Test-ExcludedPath -FullPath $_.FullName -ExcludeNames $excludeDirs)
      }
  )

  if ($candidates.Count -eq 0) {
    Write-Error "No matching source files under: $root"
    exit 5
  }

  $maxAttempts = 50
  $picked = $null
  $lines = $null
  $startLine = 0
  $found = $false

  for ($a = 0; $a -lt $maxAttempts; $a++) {
    $tryFile = $candidates | Get-Random -Count 1
    if (-not (Test-TextLikeFile -Path $tryFile.FullName)) { continue }
    try {
      $tryLines = Read-AllLinesRobust -Path $tryFile.FullName
    }
    catch {
      continue
    }
    if ($null -eq $tryLines) { continue }
    if ($tryLines.Count -ge 10) {
      $picked = $tryFile
      $lines = $tryLines
      $startLine = 1 + (Get-Random -Maximum ($lines.Count - 9))
      $found = $true
      break
    }
  }

  if (-not $found) {
    Write-Error "Could not find a text file with at least 10 lines after $maxAttempts attempts."
    exit 6
  }

  $snippetLines = @($lines[($startLine - 1)..($startLine + 8)])
  $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $rand = [guid]::NewGuid().ToString('N').Substring(0, 6)
  $snippetDir = Join-Path $repoRoot 'snippets'
  if (-not (Test-Path -LiteralPath $snippetDir)) {
    New-Item -ItemType Directory -Path $snippetDir | Out-Null
  }
  $outName = "snippet_${timestamp}_$rand.txt"
  $outPath = Join-Path $snippetDir $outName

  $relSource = $picked.FullName
  $header = @(
    "# source: $relSource"
    "# lines: $startLine-$($startLine + $snippetLines.Count - 1)"
    ""
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($outPath, ($header + $snippetLines), $utf8NoBom)

  $branch = "auto/snippet-$timestamp-$rand"
  git checkout -b $branch 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git checkout -b failed (branch may already exist): $branch"
    exit 7
  }

  git add -- "snippets/$outName" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git add failed."
    exit 8
  }

  $shortSrc = if ($relSource.Length -gt 120) { $relSource.Substring(0, 117) + '...' } else { $relSource }
  $endLine = $startLine + $snippetLines.Count - 1
  git commit -m "chore: import random snippet from external project" -m "Source: $shortSrc`nLines: $startLine-$endLine" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git commit failed. Configure user.name and user.email if this is a new repo."
    exit 9
  }

  $pushEa = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    git push -u origin $branch 2>&1 | ForEach-Object { Write-Host $_ }
  }
  finally {
    $ErrorActionPreference = $pushEa
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git push failed. Check credentials, network, and that origin accepts this branch."
    exit 10
  }

  Write-Host "Done. Branch: $branch  File: snippets\$outName"
}
finally {
  Pop-Location
}
