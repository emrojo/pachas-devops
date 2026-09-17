<#
.SYNOPSIS
    Syncs environment variables from a local .env file to GitHub Secrets using GitHub CLI (gh).

.DESCRIPTION
    Reads a local .env file (which is gitignored) and uploads secrets directly to GitHub
    without exposing them in git history or requiring manual entry in the GitHub web UI.

.PARAMETER EnvFile
    Path to the .env file. Defaults to '.env'.

.PARAMETER Mode
    'Individual' (default): Uploads each KEY=VALUE line as an individual GitHub Secret.
    'Single': Uploads the entire .env file content to a single 'ENV_CONTENT' secret.

.PARAMETER Environment
    Optional GitHub Environment name (e.g. 'production', 'staging').
    If omitted, repository-level secrets are set.

.PARAMETER Repo
    Optional target repository in 'owner/repo' format. Defaults to the current git repository.

.EXAMPLE
    .\scripts\sync-secrets.ps1
    Uploads all keys in .env as individual secrets to the current repository.

.EXAMPLE
    .\scripts\sync-secrets.ps1 -Mode Single
    Uploads the entire .env file content to the 'ENV_CONTENT' secret.

.EXAMPLE
    .\scripts\sync-secrets.ps1 -EnvFile .env.production -Environment production
    Uploads keys from .env.production to the 'production' GitHub Environment.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$EnvFile = ".env",

    [Parameter(Position = 1)]
    [ValidateSet("Individual", "Single")]
    [string]$Mode = "Individual",

    [Parameter()]
    [string]$Environment = "",

    [Parameter()]
    [string]$Repo = ""
)

# 1. Verify that GitHub CLI (gh) is installed
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[ERROR] GitHub CLI ('gh') is not installed or not in your PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "To install GitHub CLI on Windows, run in an Administrator PowerShell:" -ForegroundColor Yellow
    Write-Host "    winget install --id GitHub.cli" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After installing, restart your terminal and run:" -ForegroundColor Yellow
    Write-Host "    gh auth login" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# 2. Check GitHub CLI authentication
$authCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] You are not authenticated with GitHub CLI." -ForegroundColor Red
    Write-Host "Please run the following command to authenticate:" -ForegroundColor Yellow
    Write-Host "    gh auth login" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# 3. Check that the .env file exists
if (-not (Test-Path $EnvFile)) {
    Write-Host ""
    Write-Host "[ERROR] File '$EnvFile' not found." -ForegroundColor Red
    Write-Host "Create '$EnvFile' or copy from '.env.example' before running this script:" -ForegroundColor Yellow
    Write-Host "    Copy-Item .env.example .env" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Build common gh arguments
$commonArgs = @()
if ($Repo) {
    $commonArgs += @("--repo", $Repo)
}
if ($Environment) {
    $commonArgs += @("--env", $Environment)
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 Syncing secrets from: $EnvFile" -ForegroundColor Cyan
Write-Host "   Target mode:          $Mode" -ForegroundColor Cyan
if ($Environment) {
    Write-Host "   Target environment:   $Environment" -ForegroundColor Cyan
}
if ($Repo) {
    Write-Host "   Target repository:    $Repo" -ForegroundColor Cyan
}
Write-Host "==========================================================" -ForegroundColor Cyan

# 4. Execute sync according to selected Mode
if ($Mode -eq "Single") {
    Write-Host "[*] Uploading entire file content to secret 'ENV_CONTENT'..." -ForegroundColor Yellow
    $fileContent = Get-Content -Path $EnvFile -Raw
    
    $ghArgs = @("secret", "set", "ENV_CONTENT") + $commonArgs + @("--body", $fileContent)
    & gh @ghArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Successfully set 'ENV_CONTENT' secret." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to set 'ENV_CONTENT' secret." -ForegroundColor Red
        exit 1
    }
} else {
    # Individual mode: line by line
    $lines = Get-Content -Path $EnvFile
    $count = 0

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        # Parse KEY=VALUE (split on the first '=' only)
        $eqIndex = $trimmed.IndexOf('=')
        if ($eqIndex -le 0) {
            continue
        }

        $key = $trimmed.Substring(0, $eqIndex).Trim()
        $val = $trimmed.Substring($eqIndex + 1).Trim()

        # Remove surrounding single or double quotes if present
        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
            if ($val.Length -ge 2) {
                $val = $val.Substring(1, $val.Length - 2)
            }
        }

        Write-Host "  -> Setting secret: $key" -ForegroundColor Gray
        $ghArgs = @("secret", "set", $key) + $commonArgs + @("--body", $val)
        & gh @ghArgs

        if ($LASTEXITCODE -eq 0) {
            $count++
        } else {
            Write-Host "     [WARN] Failed to set secret '$key'" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "[OK] Sync complete! Uploaded $count secret(s) to GitHub." -ForegroundColor Green
}
