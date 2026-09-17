# Secrets Management Guide

This guide explains how to manage and upload secrets to GitHub Actions directly from a local `.env` file without ever committing sensitive data to your Git repository.

---

## 🔒 Why Local `.env` Files Are Safe

Your `.gitignore` file already contains:
```gitignore
.env
.env.*
!.env.example
```

This prevents any file named `.env`, `.env.local`, or `.env.production` from ever being tracked or pushed to GitHub. You can safely keep your credentials in `.env` on your development machine.

---

## 🚀 Quick Setup: GitHub CLI (`gh`)

The most efficient way to manage GitHub Secrets from the command line is using the official [GitHub CLI](https://cli.github.com/).

### 1. Install GitHub CLI (Windows)
Open PowerShell and run:
```powershell
winget install --id GitHub.cli
```

*(For macOS: `brew install gh` \| For Debian/Ubuntu: `sudo apt install gh`)*

### 2. Authenticate
Once installed, restart your terminal and log in:
```bash
gh auth login
```
Follow the interactive prompts (select `GitHub.com` -> `HTTPS` -> authenticate with browser or paste a personal token).

---

## ⚡ Sincronizing Secrets: 2 Methods

### Method 1: Using the Included Helper Scripts (Recommended)

This repository includes helper scripts for Windows (PowerShell & Batch) and Linux/macOS (Bash).

#### Uploading Individual Secrets:
Converts each `KEY=VALUE` line in `.env` into a separate GitHub Secret:

```cmd
# Windows (Command Prompt or double-click):
scripts\sync-secrets.bat

# Windows (PowerShell):
.\scripts\sync-secrets.ps1

# Linux / macOS:
./scripts/sync-secrets.sh
```

#### Uploading the Entire `.env` as `ENV_CONTENT` (Best for Docker Compose):
Stores the whole `.env` file as a single secret named `ENV_CONTENT`. The reusable workflow will automatically write this file onto the server before starting `docker compose`:

```cmd
# Windows Batch:
scripts\sync-secrets.bat .env Single

# Windows PowerShell:
.\scripts\sync-secrets.ps1 -Mode Single

# Linux / macOS:
./scripts/sync-secrets.sh .env Single
```

#### Uploading to a Specific Environment or Another Repository:
```powershell
# Upload to a GitHub Environment named 'production':
.\scripts\sync-secrets.ps1 -EnvFile .env.prod -Environment production

# Upload to a consumer repository from this directory:
.\scripts\sync-secrets.ps1 -Repo "my-org/my-consumer-app"
```

---

### Method 2: Native GitHub CLI Commands

If you prefer using `gh` directly without scripts:

1. **Bulk import all lines from `.env` as individual secrets**:
   ```bash
   gh secret set -f .env
   ```

2. **Upload `.env` content to the single `ENV_CONTENT` secret**:
   ```bash
   gh secret set ENV_CONTENT < .env
   ```

3. **Upload to a specific GitHub Environment**:
   ```bash
   gh secret set -f .env --env production
   ```

---

## 📝 Best Practices Checklist

- [ ] **Always inspect `.gitignore`** before creating `.env` files to confirm they are excluded.
- [ ] **Use `.env.example`** to document which variable names exist, without committing real values.
- [ ] **Rotate keys immediately** if you suspect a secret was ever exposed.
