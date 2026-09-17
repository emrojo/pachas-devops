# 🚀 Pachas DevOps: Reusable CI/CD Workflows

A central repository providing **reusable GitHub Actions workflows (`workflow_call`)** to standardize Docker image builds and automated SSH deployments across your private infrastructure.

---

## 🏗️ Pipeline Architecture

This pipeline implements the pattern recommended by GitHub and Docker:

```
[ Consumer Project ]
        │ (git push / release tag)
        ▼
[ GitHub Runner ]
   ├── 1. Checks out repository code
   ├── 2. Builds Docker image using buildx with layer caching (gha)
   └── 3. Pushes image to GitHub Container Registry (ghcr.io)
        │
        ▼ (Secure SSH connection using ed25519 key)
[ Target Server ]
   ├── 4. Navigates to the app directory (`deploy_path`)
   ├── 5. Runs `docker compose pull` to retrieve the latest image
   ├── 6. Runs `docker compose up -d` for zero-downtime recreation
   └── 7. Prunes dangling images (`docker image prune -f`)
```

---

## ⚡ Quickstart (3 Steps)

### 1. Configure Secrets in Consumer Repository
In your GitHub project, navigate to **Settings > Secrets and variables > Actions** and add:
- `SSH_HOST`: IP address or domain of your remote server.
- `SSH_USER`: SSH user on the server (recommended: `deploy`, see [Server Setup Guide](docs/server-setup.md)).
- `SSH_KEY`: Private SSH key (ed25519) without passphrase or accompanied by `SSH_PASSPHRASE`.

### 2. Prepare the Server
Create the target directory and place your `docker-compose.yml` on the server:
```bash
mkdir -p /home/deploy/apps/my-app
# You can use the template in examples/docker-compose.example.yml
```

### 3. Add Workflow to Your Project
In your consumer project, create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Application

on:
  push:
    branches: [main]

permissions:
  contents: read
  packages: write

jobs:
  deploy:
    # Replace 'YOUR_ORG_OR_USERNAME' with your GitHub organization or username
    uses: YOUR_ORG_OR_USERNAME/pachas-devops/.github/workflows/docker-build-deploy.yml@main
    secrets: inherit
    with:
      deploy_mode: 'compose'
      deploy_path: '/home/deploy/apps/my-app'
```

That's it! On every `push` to `main`, GitHub Actions will build the Docker image, publish it to `ghcr.io`, and deploy it to your server via SSH.

---

## 📋 Input Parameters (`inputs`)

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `registry` | `string` | `ghcr.io` | Container registry to push the image to. |
| `image_name` | `string` | `${{ github.repository }}` | Full image name in lowercase (excluding registry). |
| `dockerfile` | `string` | `./Dockerfile` | Path to the Dockerfile in the caller project. |
| `context` | `string` | `.` | Docker build context directory. |
| `target` | `string` | `""` | Target build stage for multi-stage Dockerfiles. |
| `build_args` | `string` | `""` | Build arguments (`KEY=VALUE`, one per line). |
| `push_image` | `boolean` | `true` | Whether to push the built image to the registry. |
| `deploy_mode` | `string` | `compose` | Deployment mode: `compose` (Docker Compose), `command` (custom shell command), or `none` (build & push only). |
| `deploy_path` | `string` | `""` | Directory on the remote server where `docker-compose.yml` or app files reside. |
| `compose_file` | `string` | `docker-compose.yml` | Compose file name on the server. |
| `compose_services` | `string` | `""` | Specific services to restart (leave empty to restart all). |
| `deploy_command` | `string` | `""` | Custom shell command to execute if `deploy_mode: command`. |
| `environment` | `string` | `""` | GitHub Deployment Environment name (`production`, `staging`). |
| `ssh_port` | `number` | `22` | Remote server SSH port. |

---

## 🔐 Secrets Reference (`secrets`)

| Secret | Required | Description |
| :--- | :---: | :--- |
| `SSH_HOST` | Yes* | Remote server IP or domain (*if `deploy_mode != none`). |
| `SSH_USER` | Yes* | SSH username on the remote server. |
| `SSH_KEY` | Yes* | Authorized private SSH key. |
| `SSH_PASSPHRASE`| No | Passphrase for encrypted private SSH key (if applicable). |
| `REGISTRY_USERNAME`| No | Registry username (defaults to `${{ github.actor }}`). |
| `REGISTRY_PASSWORD`| No | Registry token/password (defaults to `${{ secrets.GITHUB_TOKEN }}`). |
| `ENV_CONTENT` | No | Plain text content of a `.env` file to securely inject onto the server before deployment. |

> [!TIP]
> When calling the workflow with `secrets: inherit`, you do not need to list individual secrets; all available secrets are inherited automatically.

---

## 📤 Outputs (`outputs`)

The workflow produces the following outputs for subsequent steps or jobs:
- `image_tag`: Primary generated tag (e.g. `sha-1a2b3c4` or release tag).
- `image_full_name`: Full image identifier including registry and name (e.g. `ghcr.io/user/repo`).

---

## 📁 Included Examples & Docs

- [Basic Deploy Example](examples/basic-deploy.yml): Minimal 15-line caller pipeline.
- [Advanced Compose Deploy](examples/compose-deploy.yml): Production release with environments and `.env` injection.
- [Docker Compose Template](examples/docker-compose.example.yml): Ready-to-use Compose template for your target host.
- [Server Setup Guide](docs/server-setup.md): Complete setup guide for SSH keys, Docker user permissions, and security on Linux.
- [Secrets Management Guide](docs/secrets-management.md): Guide and scripts to sync local `.env` variables to GitHub Secrets safely.

---

## 🏷️ Workflow Versioning

Pin workflow calls to a tagged version to prevent breaking changes:

```yaml
# Pinned to a stable major release (Recommended):
uses: YOUR_ORG_OR_USERNAME/pachas-devops/.github/workflows/docker-build-deploy.yml@v1

# Tracking the main branch with latest updates:
uses: YOUR_ORG_OR_USERNAME/pachas-devops/.github/workflows/docker-build-deploy.yml@main
```
