#Requires -Version 5.1
param(
  [Parameter(Mandatory = $false)]
  [string] $SourceRoot,

  [Parameter(Mandatory = $false)]
  [string] $ConfigPath,

  [switch] $EmitOutputPaths,

  [switch] $EmitIterations
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $PSScriptRoot 'gencodebat.config.json'
}

$config = $null
if (Test-Path -LiteralPath $ConfigPath) {
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-ConfigRelativePath {
  param([string] $PathLike)
  if ([string]::IsNullOrWhiteSpace($PathLike)) { return $null }
  $t = $PathLike.Trim()
  if ([IO.Path]::IsPathRooted($t)) { return [IO.Path]::GetFullPath($t) }
  return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $t))
}

$outBase = if ($null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.OutputBaseDirectory)) {
  Resolve-ConfigRelativePath -PathLike $config.OutputBaseDirectory
}
else {
  [IO.Path]::GetFullPath($PSScriptRoot)
}

$snippetDirName = if ($null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.SnippetDirectory)) {
  $config.SnippetDirectory
}
else { 'snippets' }

$funcFileName = if ($null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.FunctionClassFile)) {
  $config.FunctionClassFile
}
else { 'Function.class' }

$funcTestFileName = if ($null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.FunctionTestClassFile)) {
  $config.FunctionTestClassFile
}
else { 'FunctionTest.class' }

$snippetDir = [IO.Path]::GetFullPath((Join-Path $outBase $snippetDirName))
$pathFunction = [IO.Path]::GetFullPath((Join-Path $snippetDir $funcFileName))
$pathFunctionTest = [IO.Path]::GetFullPath((Join-Path $snippetDir $funcTestFileName))

if ($EmitOutputPaths) {
  Write-Output ($pathFunction + '|' + $pathFunctionTest)
  exit 0
}

if ($EmitIterations) {
  $iter = 10
  if ($null -ne $config -and $null -ne $config.Iterations) {
    try {
      $iter = [Math]::Max(1, [int]$config.Iterations)
    }
    catch {
      $iter = 10
    }
  }
  Write-Output $iter
  exit 0
}

if ([string]::IsNullOrWhiteSpace($SourceRoot) -and $null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.SourceRoot)) {
  $SourceRoot = $config.SourceRoot
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  Write-Error "SourceRoot is empty. Pass -SourceRoot, or set SourceRoot in gencodebat.config.json next to this script."
  exit 2
}

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

function Select-RandomSnippet {
  param(
    [Parameter(Mandatory = $true)]
    [object[]] $Candidates,
    [int] $MaxAttempts = 50
  )
  $picked = $null
  $lines = $null
  $startLine = 0
  for ($a = 0; $a -lt $MaxAttempts; $a++) {
    $tryFile = $Candidates | Get-Random -Count 1
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
      $snippetLines = @($lines[($startLine - 1)..($startLine + 8)])
      $endLine = $startLine + $snippetLines.Count - 1
      return [pscustomobject]@{
        SourcePath = $picked.FullName
        StartLine  = $startLine
        EndLine    = $endLine
        BodyLines  = $snippetLines
      }
    }
  }
  return $null
}

function Append-SnippetToFile {
  param(
    [Parameter(Mandatory = $true)]
    [string] $FilePath,
    [Parameter(Mandatory = $true)]
    [pscustomobject] $Snippet,
    [Parameter(Mandatory = $true)]
    [string] $RunStamp,
    [Parameter(Mandatory = $true)]
    [System.Text.Encoding] $Encoding
  )
  $nl = [Environment]::NewLine
  $header = @(
    ''
    "===== $RunStamp ====="
    "# source: $($Snippet.SourcePath)"
    "# lines: $($Snippet.StartLine)-$($Snippet.EndLine)"
    ''
  )
  $chunk = ($header + $Snippet.BodyLines) -join $nl
  [System.IO.File]::AppendAllText($FilePath, $chunk + $nl, $Encoding)
}

$excludeDirs = @('.git', 'node_modules', 'bin', 'obj', 'dist', 'build')
$allowedExt = @(
  '.cs', '.ts', '.tsx', '.js', '.jsx', '.py', '.java', '.go', '.rs', '.md', '.txt'
) | ForEach-Object { $_.ToLowerInvariant() }

$root = Resolve-ConfigRelativePath -PathLike $SourceRoot
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
  Write-Error "SourceRoot is not a directory: $root"
  exit 2
}

if (-not (Test-Path -LiteralPath $snippetDir)) {
  New-Item -ItemType Directory -Path $snippetDir | Out-Null
}

foreach ($p in @($pathFunction, $pathFunctionTest)) {
  if (-not (Test-Path -LiteralPath $p)) {
    [System.IO.File]::WriteAllText($p, '', (New-Object System.Text.UTF8Encoding $false))
  }
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

$snippetA = Select-RandomSnippet -Candidates $candidates
if ($null -eq $snippetA) {
  Write-Error "Could not find a text file with at least 10 lines after 50 attempts (Function.class block)."
  exit 6
}

$snippetB = Select-RandomSnippet -Candidates $candidates
if ($null -eq $snippetB) {
  Write-Error "Could not find a text file with at least 10 lines after 50 attempts (FunctionTest.class block)."
  exit 6
}

$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

Append-SnippetToFile -FilePath $pathFunction -Snippet $snippetA -RunStamp $runStamp -Encoding $utf8NoBom
Append-SnippetToFile -FilePath $pathFunctionTest -Snippet $snippetB -RunStamp $runStamp -Encoding $utf8NoBom

Write-Host "Done. Appended to:"
Write-Host "  $pathFunction"
Write-Host "  $pathFunctionTest"
