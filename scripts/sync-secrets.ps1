<#
.SYNOPSIS
    Syncs environment variables from a local .env file to GitHub Secrets using GitHub CLI (gh).

.DESCRIPTION
    Reads a local .env file (which is gitignored) and uploads secrets directly to GitHub.
    Automatically supports loading SSH_KEY from a local file path (SSH_KEY_PATH or -KeyPath).

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

.PARAMETER KeyPath
    Optional explicit path to the private SSH key file. Overrides SSH_KEY_PATH in .env.

.EXAMPLE
    .\scripts\sync-secrets.ps1 -Repo "emrojo/scan-bills"
    Uploads all keys in .env as individual secrets to emrojo/scan-bills.

.EXAMPLE
    .\scripts\sync-secrets.ps1 -KeyPath ~/.ssh/id_ed25519 -Repo "emrojo/scan-bills"
    Explicitly loads the SSH key from ~/.ssh/id_ed25519 and syncs to GitHub.
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
    [string]$Repo = "",

    [Parameter()]
    [string]$KeyPath = ""
)

# Helper function to expand paths like ~ or relative paths
function Resolve-LocalPath ([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    
    # Expand ~ to user home
    if ($path.StartsWith("~")) {
        $homeDir = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        $path = Join-Path $homeDir $path.Substring(1).TrimStart('/', '\')
    }
    
    # Resolve relative or absolute path
    if (Test-Path $path) {
        return (Resolve-Path $path).Path
    }
    return $path
}

# 1. Verify that GitHub CLI (gh) is installed
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[ERROR] GitHub CLI ('gh') is not installed or not in your PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "To install GitHub CLI on Windows, run in PowerShell:" -ForegroundColor Yellow
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

# 4. Parse .env into a dictionary (supporting multiline quoted values)
$parsedVars = [ordered]@{}
$rawContent = Get-Content -Path $EnvFile -Raw
# Normalize CRLF to LF
$rawContent = $rawContent -replace "\r\n", "`n"
$lines = $rawContent -split "`n"

$currentKey = $null
$currentValue = ""
$inQuotes = $false
$quoteChar = ""

foreach ($line in $lines) {
    if (-not $inQuotes) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        $eqIndex = $trimmed.IndexOf('=')
        if ($eqIndex -le 0) { continue }

        $key = $trimmed.Substring(0, $eqIndex).Trim()
        $val = $trimmed.Substring($eqIndex + 1)

        # Check if value starts with a quote
        $valTrimStart = $val.TrimStart()
        if ($valTrimStart.StartsWith('"') -or $valTrimStart.StartsWith("'")) {
            $quoteChar = $valTrimStart.Substring(0, 1)
            $valAfterQuote = $valTrimStart.Substring(1)

            # Check if quote ends on the same line
            if ($valAfterQuote.EndsWith($quoteChar) -and $valAfterQuote.Length -ge 1) {
                $parsedVars[$key] = $valAfterQuote.Substring(0, $valAfterQuote.Length - 1)
            } else {
                $inQuotes = $true
                $currentKey = $key
                $currentValue = $valAfterQuote
            }
        } else {
            $parsedVars[$key] = $val.Trim()
        }
    } else {
        # Inside multiline quoted string
        if ($line.EndsWith($quoteChar)) {
            $currentValue += "`n" + $line.Substring(0, $line.Length - 1)
            $parsedVars[$currentKey] = $currentValue
            $inQuotes = $false
            $currentKey = $null
            $currentValue = ""
        } else {
            $currentValue += "`n" + $line
        }
    }
}

# 5. Handle SSH Key File Path if provided via parameter or in .env
$effectiveKeyPath = $KeyPath
if ([string]::IsNullOrWhiteSpace($effectiveKeyPath)) {
    if ($parsedVars.Contains("SSH_KEY_PATH")) {
        $effectiveKeyPath = $parsedVars["SSH_KEY_PATH"]
    } elseif ($parsedVars.Contains("SSH_KEY_FILE")) {
        $effectiveKeyPath = $parsedVars["SSH_KEY_FILE"]
    } elseif ($parsedVars.Contains("SSH_KEY")) {
        # Check if the value in SSH_KEY is actually a path to a file
        $resolvedCandidate = Resolve-LocalPath $parsedVars["SSH_KEY"]
        if (Test-Path $resolvedCandidate -PathType Leaf) {
            $effectiveKeyPath = $resolvedCandidate
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($effectiveKeyPath)) {
    $resolvedKey = Resolve-LocalPath $effectiveKeyPath
    if (Test-Path $resolvedKey -PathType Leaf) {
        Write-Host "[+] Reading SSH key file from: $resolvedKey" -ForegroundColor Green
        $keyContent = Get-Content -Path $resolvedKey -Raw
        
        # Verify it has valid SSH header
        if ($keyContent -match "BEGIN .* PRIVATE KEY") {
            $parsedVars["SSH_KEY"] = $keyContent.Trim()
            # Remove helper path keys from uploading directly
            $parsedVars.Remove("SSH_KEY_PATH")
            $parsedVars.Remove("SSH_KEY_FILE")
        } else {
            Write-Host "[WARN] File at '$resolvedKey' does not look like a private SSH key (missing 'BEGIN ... PRIVATE KEY')." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERROR] Specified SSH key file not found: $effectiveKeyPath" -ForegroundColor Red
        exit 1
    }
}

# 6. Execute sync
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
    # Individual mode
    $count = 0
    foreach ($entry in $parsedVars.GetEnumerator()) {
        $k = $entry.Key
        $v = $entry.Value

        # Convert literal \n into real newlines if user wrote a one-liner with \n
        if ($v -match "\\n") {
            $v = $v -replace "\\n", "`n"
        }

        Write-Host "  -> Setting secret: $k" -ForegroundColor Gray
        $ghArgs = @("secret", "set", $k) + $commonArgs + @("--body", $v)
        & gh @ghArgs

        if ($LASTEXITCODE -eq 0) {
            $count++
        } else {
            Write-Host "     [WARN] Failed to set secret '$k'" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "[OK] Sync complete! Uploaded $count secret(s) to GitHub." -ForegroundColor Green
}
