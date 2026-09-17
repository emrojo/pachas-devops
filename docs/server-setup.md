# Deployment Server Setup Guide

This guide walks through configuring a Linux server (Ubuntu/Debian) to securely receive automated deployments from GitHub Actions over SSH.

---

## 1. Create a Dedicated Deployment User

Running CI/CD deployments directly as `root` is discouraged. Instead, create an unprivileged user dedicated to deployments:

```bash
# 1. Create the 'deploy' user with home directory
sudo adduser --disabled-password --gecos "" deploy

# 2. Add the user to the 'docker' group to run containers without sudo
sudo usermod -aG docker deploy
```

> [!NOTE]
> To apply the group membership without logging out, run `newgrp docker` or reconnect the SSH session.

---

## 2. Configure SSH Key Authentication for GitHub Actions

GitHub Actions requires a private SSH key to authenticate with the target server.

### On your local machine (or on the server):
Generate a dedicated ED25519 key pair for CI/CD:

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy_key
```

This creates two files:
- `github_deploy_key`: **Private key** (save in GitHub Secrets as `SSH_KEY`).
- `github_deploy_key.pub`: **Public key** (installed on the server).

### On the target server:
Log in as the `deploy` user and authorize the public key:

```bash
# Switch to the deploy user
sudo su - deploy

# Create .ssh directory with strict permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Append your public key content to authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... github-actions-deploy" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## 3. Directory Layout for Applications

Organize application folders on the server:

```bash
# As the deploy user:
mkdir -p ~/apps/my-app
cd ~/apps/my-app

# Place your docker-compose.yml here (see template in examples/docker-compose.example.yml)
nano docker-compose.yml

# (Optional) If you maintain persistent local environment variables:
touch .env
chmod 600 .env
```

---

## 4. Accessing Private GitHub Container Registry (`ghcr.io`) Images

### For PUBLIC Repositories:
No server authentication is needed. `docker compose pull` pulls public packages anonymously.

### For PRIVATE Repositories:
The server requires read permissions to pull the image. You have two options:

#### Option A: Automatic Authentication via Workflow (Recommended)
The `pachas-devops` workflow automatically executes `docker login ghcr.io` during deployment using credentials supplied by GitHub Actions.

#### Option B: Persistent Server Login
Generate a GitHub Personal Access Token (PAT) with `read:packages` scope and run on the server once:

```bash
echo "YOUR_GITHUB_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

---

## 5. Firewall Configuration (UFW)

Ensure SSH (default port 22) and application traffic ports (HTTP/HTTPS) are allowed through the firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```
