# Validate prerequisites for running Copilot Usage Advanced Dashboard locally with Docker Compose.
# Run this script before 'docker-compose up' to catch configuration problems early.
#
# Usage: .\scripts\Validate-LocalSetup.ps1

Write-Host ""
Write-Host "=== Local Setup Validation ===" -ForegroundColor Cyan
Write-Host ""

$Errors   = 0
$Warnings = 0

# -------------------------------------------------------------------------
# 1. Docker
# -------------------------------------------------------------------------
Write-Host "Checking Docker..."
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: 'docker' is not installed or not on PATH." -ForegroundColor Red
    Write-Host "  Install Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    $Errors++
} else {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Docker daemon is not running. Start Docker Desktop and try again." -ForegroundColor Red
        $Errors++
    } else {
        Write-Host "  OK: $(docker --version)" -ForegroundColor Green
    }
}

# -------------------------------------------------------------------------
# 2. Docker Compose
# -------------------------------------------------------------------------
Write-Host "Checking Docker Compose..."
$composeV2 = docker compose version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK: $composeV2" -ForegroundColor Green
} elseif (Get-Command "docker-compose" -ErrorAction SilentlyContinue) {
    Write-Host "  OK (standalone): $(docker-compose --version)" -ForegroundColor Green
} else {
    Write-Host "  ERROR: 'docker compose' is not available." -ForegroundColor Red
    Write-Host "  Ensure Docker Desktop is up to date, or install the Compose plugin." -ForegroundColor Yellow
    $Errors++
}

# -------------------------------------------------------------------------
# 3. .env file
# -------------------------------------------------------------------------
Write-Host "Checking .env file..."
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path "$RepoRoot\.env")) {
    Write-Host "  ERROR: .env file not found at $RepoRoot\.env" -ForegroundColor Red
    Write-Host "  Create it by running:" -ForegroundColor Yellow
    Write-Host "    copy .env.template .env" -ForegroundColor Yellow
    Write-Host "  Then edit .env and set GITHUB_PAT and ORGANIZATION_SLUGS." -ForegroundColor Yellow
    $Errors++
} else {
    Write-Host "  OK: .env file exists." -ForegroundColor Green
    # Load .env for variable checks below
    Get-Content "$RepoRoot\.env" | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]*)=(.*)$") {
            $key   = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "Env:$key" -Value $value
        }
    }
}

# -------------------------------------------------------------------------
# 4. Required environment variables
# -------------------------------------------------------------------------
Write-Host "Checking required environment variables..."

if (-not $env:GITHUB_PAT -or $env:GITHUB_PAT -eq "ghp_your_token_here") {
    Write-Host "  ERROR: GITHUB_PAT is not set or still contains the placeholder value." -ForegroundColor Red
    Write-Host "  Create a Personal Access Token with the following scopes:" -ForegroundColor Yellow
    Write-Host "    - manage_billing:copilot" -ForegroundColor Yellow
    Write-Host "    - read:enterprise" -ForegroundColor Yellow
    Write-Host "    - read:org" -ForegroundColor Yellow
    Write-Host "  Token creation: https://github.com/settings/tokens" -ForegroundColor Yellow
    Write-Host "  Then set GITHUB_PAT=ghp_<your-token> in .env" -ForegroundColor Yellow
    $Errors++
} else {
    $PatPreview = $env:GITHUB_PAT.Substring(0, [Math]::Min(7, $env:GITHUB_PAT.Length)) + "***"
    Write-Host "  OK: GITHUB_PAT is set ($PatPreview)." -ForegroundColor Green
}

if ((-not $env:ORGANIZATION_SLUGS -or $env:ORGANIZATION_SLUGS -eq "your-org-name") -and -not $env:ENTERPRISE_SLUGS) {
    Write-Host "  ERROR: Neither ORGANIZATION_SLUGS nor ENTERPRISE_SLUGS is set." -ForegroundColor Red
    Write-Host "  Set at least one of:" -ForegroundColor Yellow
    Write-Host "    ORGANIZATION_SLUGS=my-github-org          (for org-level data)" -ForegroundColor Yellow
    Write-Host "    ENTERPRISE_SLUGS=my-github-enterprise     (for enterprise-level data)" -ForegroundColor Yellow
    Write-Host "    ORGANIZATION_SLUGS=standalone:my-slug     (for Copilot Standalone)" -ForegroundColor Yellow
    $Errors++
} elseif ($env:ENTERPRISE_SLUGS -and (-not $env:ORGANIZATION_SLUGS -or $env:ORGANIZATION_SLUGS -eq "your-org-name")) {
    Write-Host "  OK: ENTERPRISE_SLUGS is set ($($env:ENTERPRISE_SLUGS))." -ForegroundColor Green
} else {
    Write-Host "  OK: ORGANIZATION_SLUGS is set ($($env:ORGANIZATION_SLUGS))." -ForegroundColor Green
}

# -------------------------------------------------------------------------
# 5. Port availability
# -------------------------------------------------------------------------
Write-Host "Checking port availability..."

function Test-Port {
    param([int]$Port, [string]$Service)
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Host "  WARNING: Port $Port ($Service) is already in use." -ForegroundColor DarkYellow
        Write-Host "  Stop the conflicting process or edit docker-compose.yml to use a different host port." -ForegroundColor DarkYellow
        $script:Warnings++
    } else {
        Write-Host "  OK: Port $Port ($Service) is available." -ForegroundColor Green
    }
}

Test-Port -Port 8080 -Service "Grafana"
Test-Port -Port 9200 -Service "Elasticsearch"

# -------------------------------------------------------------------------
# 6. Summary
# -------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($Errors -eq 0 -and $Warnings -eq 0) {
    Write-Host "All checks passed. You are ready to start the dashboard:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  docker-compose up -d" -ForegroundColor White
    Write-Host ""
    Write-Host "Then open http://localhost:8080 (admin / copilot)." -ForegroundColor White
} elseif ($Errors -eq 0) {
    Write-Host "Validation passed with $Warnings warning(s). Review the warnings above, then run:" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "  docker-compose up -d" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Validation FAILED with $Errors error(s) and $Warnings warning(s)." -ForegroundColor Red
    Write-Host "Fix the errors listed above before running docker-compose." -ForegroundColor Red
    Write-Host ""
    exit 1
}
