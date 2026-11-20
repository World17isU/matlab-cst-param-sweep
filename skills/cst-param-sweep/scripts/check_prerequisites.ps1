<#
.SYNOPSIS
Checks prerequisites for the MATLAB-CST parameter sweep.

.DESCRIPTION
Verifies the repository layout, the MATLAB executable, CST processes, write
access to results/, and whether a local configuration exists. It does not start
MATLAB or CST; the only write is a temporary probe under results/.

.PARAMETER RepoRoot
Repository root. Defaults to the current directory.

.EXAMPLE
powershell -NoProfile -File .\skills\cst-param-sweep\scripts\check_prerequisites.ps1 -RepoRoot .
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Ok {
    param([string]$Message)
    Write-Host "[ok]   $Message" -ForegroundColor Green
}

function Add-Warn {
    param([string]$Message)
    $warnings.Add($Message) | Out-Null
    Write-Host "[warn] $Message" -ForegroundColor Yellow
}

function Add-Fail {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
    Write-Host "[fail] $Message" -ForegroundColor Red
}

Write-Host "Repository: $RepoRoot"

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    Add-Fail 'Repository folder does not exist.'
    exit 1
}

$required = @(
    'run_sweep.m',
    'src\+cstsweep\Config.m',
    'src\+cstsweep\SweepRunner.m',
    'examples\parameters_example.csv',
    'skills\cst-param-sweep\SKILL.md'
)
foreach ($relative in $required) {
    if (Test-Path -LiteralPath (Join-Path $RepoRoot $relative)) {
        Add-Ok "found $relative"
    }
    else {
        Add-Fail "missing $relative"
    }
}

$matlab = Get-Command matlab -ErrorAction SilentlyContinue
if ($null -ne $matlab) {
    Add-Ok "MATLAB on PATH: $($matlab.Source)"
}
else {
    $known = @()
    $matlabRoot = 'C:\Program Files\MATLAB'
    if (Test-Path -LiteralPath $matlabRoot) {
        $known = @(Get-ChildItem -LiteralPath $matlabRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'bin\matlab.exe' } |
            Where-Object { Test-Path -LiteralPath $_ })
    }
    if ($known.Count -gt 0) {
        Add-Warn "MATLAB is not on PATH; found $($known[0]). Add its bin folder to PATH or call it by full path."
    }
    else {
        Add-Fail 'MATLAB executable not found. Install MATLAB R2021a+ or add its bin folder to PATH.'
    }
}

$cstProcesses = @(Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match 'CST|DesignEnvironment' })
if ($cstProcesses.Count -gt 0) {
    $names = ($cstProcesses | ForEach-Object { $_.ProcessName } | Sort-Object -Unique) -join ', '
    Add-Ok "CST process detected: $names"
}
else {
    Add-Warn 'No CST process detected. Open CST Studio Suite and the project before a real sweep; dry runs are unaffected.'
}

$resultsDir = Join-Path $RepoRoot 'results'
$probe = Join-Path $resultsDir ('.write-probe-' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    New-Item -ItemType Directory -Path $resultsDir -Force -ErrorAction Stop | Out-Null
    Set-Content -LiteralPath $probe -Value 'ok' -ErrorAction Stop
    Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
    Add-Ok 'results/ is writable'
}
catch {
    Add-Fail "results/ is not writable: $($_.Exception.Message)"
}

$localConfig = Join-Path $RepoRoot 'config\local_config.m'
if (Test-Path -LiteralPath $localConfig) {
    Add-Ok 'local configuration present'
}
else {
    Add-Warn 'config/local_config.m not found; copy config/local_config_example.m and rename the function to local_config.'
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "Not ready: $($failures.Count) failure(s), $($warnings.Count) warning(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Prerequisites OK ($($warnings.Count) warning(s))." -ForegroundColor Green
exit 0
