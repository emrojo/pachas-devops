# Guía de Configuración del Servidor de Despliegue

Esta guía describe los pasos para preparar tu servidor Linux (Ubuntu/Debian) para recibir despliegues automáticos desde GitHub Actions de forma segura.

---

## 1. Crear Usuario de Despliegue Dedicado

Es una buena práctica de seguridad no usar `root` para los despliegues de CI/CD:

```bash
# 1. Crear el usuario 'deploy' con su carpeta de inicio
sudo adduser --disabled-password --gecos "" deploy

# 2. Agregar el usuario al grupo 'docker' para que pueda ejecutar contenedores sin sudo
sudo usermod -aG docker deploy
```

> [!NOTE]
> Para aplicar el cambio de grupo sin reiniciar la sesión, ejecuta `newgrp docker` o reinicia la sesión SSH del usuario.

---

## 2. Configurar la Llave SSH para GitHub Actions

GitHub Actions necesita una llave SSH privada para autenticarse contra el servidor.

### En tu máquina local (o en el servidor):
Genera un par de llaves exclusivo para CI/CD con algoritmo ED25519 (más seguro y rápido):

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy_key
```

Esto generará dos archivos:
- `github_deploy_key`: **Llave privada** (la guardarás en GitHub Secrets: `SSH_KEY`).
- `github_deploy_key.pub`: **Llave pública** (se coloca en el servidor).

### En el servidor destino:
Inicia sesión como el usuario `deploy` e instala la llave pública:

```bash
# Entrar como usuario deploy
sudo su - deploy

# Crear directorio .ssh con permisos restrictivos
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Pegar el contenido de github_deploy_key.pub en authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... github-actions-deploy" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## 3. Estructura de Directorios para Aplicaciones

Crea una estructura organizada para tus proyectos en el servidor:

```bash
# Como usuario deploy:
mkdir -p ~/apps/mi-proyecto
cd ~/apps/mi-proyecto

# Crear tu archivo docker-compose.yml (ver plantilla en examples/docker-compose.example.yml)
nano docker-compose.yml

# (Opcional) Si manejas variables de entorno locales fijas:
touch .env
chmod 600 .env
```

---

## 4. Acceso a Imágenes Privadas de GitHub Container Registry (`ghcr.io`)

### Si tu repositorio es PÚBLICO:
No requieres autenticación en el servidor. `docker compose pull` descargará la imagen directamente sin credenciales.

### Si tu repositorio es PRIVADO:
El servidor necesita permisos de lectura para descargar la imagen. Tienes dos opciones recomendadas:

#### Opción A: Autenticación automática mediante el Workflow (Recomendada)
El workflow de `pachas-devops` ejecuta automáticamente `docker login ghcr.io` durante el despliegue usando las credenciales enviadas por GitHub Actions.

#### Opción B: Inicio de sesión persistente en el servidor
Genera un Personal Access Token (PAT) en GitHub con el scope `read:packages` y ejecuta en el servidor una única vez:

```bash
echo "TU_GITHUB_PAT" | docker login ghcr.io -u TU_USUARIO_GITHUB --password-stdin
```

---

## 5. Verificación de Seguridad del Firewall (UFW)

Asegúrate de permitir el puerto SSH (por defecto 22) y los puertos HTTP/HTTPS de tus aplicaciones:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```
