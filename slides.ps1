git clone --depth 1 https://github.com/cs21206-iitkgp/cs21206-iitkgp.github.io.git
$repoDir = "cs21206-iitkgp.github.io"
$spDir = Get-ChildItem -Path "$repoDir/sp*" -Directory | Select-Object -First 1

if ($spDir) {
    # Only copy folders (like Slides) to avoid picking up root yml/html files
    Get-ChildItem -Path $spDir.FullName -Directory | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "." -Recurse -Force
    }
}

# Cleanup root level yml and html files
Get-ChildItem -Path "." -File | Where-Object { $_.Extension -in @(".yml", ".html") } | Remove-Item -Force

if (Test-Path "Slides") {
    # Keep only presentation files in Slides
    Get-ChildItem -Path "Slides" -Recurse -File | Where-Object { $_.Extension -notin @(".pdf", ".ppt", ".pptx") } | Remove-Item -Force
}

Remove-Item -Path $repoDir -Recurse -Force -ErrorAction SilentlyContinue

# ── Python environment setup ────────────────────────────────────────────────
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptRoot) { $scriptRoot = Get-Location }

$venvDir  = Join-Path $scriptRoot ".venv"
$pyScript = Join-Path (Join-Path $scriptRoot "cod") "duplicatepageremover.py"

# Find a usable Python 3 interpreter
$pythonCmd = $null
foreach ($candidate in @("python3", "python", "py")) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found) {
        $ver = & $found.Source --version 2>&1
        if ($ver -match "Python 3") {
            $pythonCmd = $found.Source
            break
        }
    }
}
if (-not $pythonCmd) {
    Write-Host "ERROR: Python 3 not found on PATH. Install Python 3.8+ and try again." -ForegroundColor Red
    exit 1
}
Write-Host "Using Python: $pythonCmd"

# Create venv if it doesn't exist
if (-not (Test-Path $venvDir)) {
    Write-Host "Creating virtual environment in $venvDir ..."
    & $pythonCmd -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create virtual environment." -ForegroundColor Red
        exit 1
    }
}

# Determine venv python/pip paths (cross-platform)
if ($IsLinux -or $IsMacOS) {
    $venvPython = Join-Path (Join-Path $venvDir "bin") "python"
    $venvPip    = Join-Path (Join-Path $venvDir "bin") "pip"
} else {
    $venvPython = Join-Path (Join-Path $venvDir "Scripts") "python.exe"
    $venvPip    = Join-Path (Join-Path $venvDir "Scripts") "pip.exe"
}

# Install required packages if missing
$requiredPackages = @("pymupdf")
foreach ($pkg in $requiredPackages) {
    $check = & $venvPython -c "import importlib; importlib.import_module('fitz')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing $pkg ..."
        & $venvPip install $pkg
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to install $pkg." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "$pkg already installed."
    }
}

# ── Run duplicate page remover on Slides/sec1 ───────────────────────────────
$slidesDir = Join-Path $scriptRoot "Slides"
$srcDir = Join-Path $slidesDir "sec1"
$dstDir = Join-Path $slidesDir "sec1 Processed"

if (-not (Test-Path $srcDir)) {
    Write-Host "ERROR: sec1 directory not found at $srcDir" -ForegroundColor Red
    exit 1
}

Write-Host "`n========== Processing sec1 ==========" -ForegroundColor Cyan
& $venvPython $pyScript $srcDir $dstDir
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Processing sec1 finished with errors." -ForegroundColor Yellow
}

Write-Host "`nAll done!" -ForegroundColor Green