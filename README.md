# 🚀 Pachas DevOps: Reusable CI/CD Workflows

Repositorio base con **workflows reutilizables (`workflow_call`)** de GitHub Actions para estandarizar la compilación de imágenes Docker y su despliegue automatizado por SSH en tu infraestructura privada.

---

## 🏗️ Arquitectura del Pipeline

El flujo implementa la arquitectura recomendada por GitHub y Docker:

```
[ Proyecto Consumidor ]
        │ (git push / release tag)
        ▼
[ GitHub Runner ]
   ├── 1. Descarga el código del proyecto
   ├── 2. Construye la imagen Docker con buildx y caché optimizado
   └── 3. Publica la imagen en GitHub Container Registry (ghcr.io)
        │
        ▼ (Conexión SSH segura con llave ed25519)
[ Servidor de Destino ]
   ├── 4. Accede al directorio de la app (`deploy_path`)
   ├── 5. Ejecuta `docker compose pull` para obtener la nueva imagen
   ├── 6. Ejecuta `docker compose up -d` para recrear los contenedores sin caída
   └── 7. Limpia imágenes huérfanas (`docker image prune -f`)
```

---

## ⚡ Inicio Rápido (3 Pasos)

### 1. Configura los Secretos en tu Repositorio Consumidor
En tu proyecto de GitHub ve a **Settings > Secrets and variables > Actions** y añade:
- `SSH_HOST`: Dirección IP o dominio de tu servidor.
- `SSH_USER`: Usuario del servidor (recomendado: `deploy`, ver [Guía de Servidor](docs/server-setup.md)).
- `SSH_KEY`: Llave privada SSH (ed25519) sin contraseña o con `SSH_PASSPHRASE`.

### 2. Prepara el Servidor
Crea el directorio y coloca tu `docker-compose.yml` en el servidor:
```bash
mkdir -p /home/deploy/apps/mi-app
# Puedes usar la plantilla en examples/docker-compose.example.yml
```

### 3. Agrega el Workflow a tu Proyecto
En tu proyecto, crea `.github/workflows/deploy.yml`:

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
    # Reemplaza 'ORGANIZACION_O_USUARIO' por tu usuario/organización de GitHub
    uses: ORGANIZACION_O_USUARIO/pachas-devops/.github/workflows/docker-build-deploy.yml@main
    secrets: inherit
    with:
      deploy_mode: 'compose'
      deploy_path: '/home/deploy/apps/mi-app'
```

¡Listo! Cada vez que hagas `push` a `main`, GitHub Actions compilará la imagen, la subirá a `ghcr.io` y la desplegará en tu servidor.

---

## 📋 Catálogo de Parámetros (`inputs`)

| Parámetro | Tipo | Por Defecto | Descripción |
| :--- | :--- | :--- | :--- |
| `registry` | `string` | `ghcr.io` | Registro de contenedores al que se publicará la imagen. |
| `image_name` | `string` | `${{ github.repository }}` | Nombre de la imagen en minúsculas (sin incluir el registro). |
| `dockerfile` | `string` | `./Dockerfile` | Ruta al Dockerfile en el proyecto llamador. |
| `context` | `string` | `.` | Contexto de construcción de Docker. |
| `target` | `string` | `""` | Target específico para Dockerfiles multi-stage. |
| `build_args` | `string` | `""` | Argumentos de compilación (`KEY=VALUE`, uno por línea). |
| `push_image` | `boolean` | `true` | Si se debe publicar la imagen en el registro. |
| `deploy_mode` | `string` | `compose` | Modo de despliegue: `compose` (Docker Compose), `command` (script custom) o `none` (solo compilar). |
| `deploy_path` | `string` | `""` | Ruta en el servidor donde reside el `docker-compose.yml` o app. |
| `compose_file` | `string` | `docker-compose.yml` | Nombre del archivo compose en el servidor. |
| `compose_services` | `string` | `""` | Servicios específicos a reiniciar (vacío reinicia todos). |
| `deploy_command` | `string` | `""` | Comando de shell a ejecutar en el servidor si `deploy_mode: command`. |
| `environment` | `string` | `""` | Nombre del GitHub Environment (`production`, `staging`). |
| `ssh_port` | `number` | `22` | Puerto SSH del servidor remoto. |

---

## 🔐 Catálogo de Secretos (`secrets`)

| Secreto | Requerido | Descripción |
| :--- | :---: | :--- |
| `SSH_HOST` | Sí* | IP o dominio del servidor remoto (*si `deploy_mode != none`). |
| `SSH_USER` | Sí* | Usuario para la sesión SSH en el servidor. |
| `SSH_KEY` | Sí* | Llave privada SSH autorizada en el servidor. |
| `SSH_PASSPHRASE`| No | Contraseña de descifrado de la llave SSH privada (si aplica). |
| `REGISTRY_USERNAME`| No | Usuario del registro (por defecto: `${{ github.actor }}`). |
| `REGISTRY_PASSWORD`| No | Token/password del registro (por defecto: `${{ secrets.GITHUB_TOKEN }}`). |
| `ENV_CONTENT` | No | Contenido plano de variables de entorno `.env` que el workflow inyectará en el servidor antes de desplegar. |

> [!TIP]
> Si en el proyecto consumidor usas `secrets: inherit`, no necesitas declarar cada secreto manualmente en la llamada al workflow; se transmitirán todos los secretos accesibles automáticamente.

---

## 📤 Salidas (`outputs`)

El workflow expone las siguientes variables para pasos posteriores si se necesitan:
- `image_tag`: La etiqueta principal generada (por ejemplo `sha-1a2b3c4` o número de versión).
- `image_full_name`: Nombre completo de la imagen con registro (por ejemplo `ghcr.io/usuario/repo`).

---

## 📁 Ejemplos Incluidos

- [Ejemplo Básico de Consumo](examples/basic-deploy.yml): El pipeline mínimo recomendado de 10 líneas.
- [Ejemplo Avanzado con Entornos y `.env`](examples/compose-deploy.yml): Despliegue a producción con secretos inyectados y etiquetas semánticas.
- [Plantilla de Docker Compose](examples/docker-compose.example.yml): Archivo `docker-compose.yml` listo para alojar en tu servidor.
- [Guía de Preparación del Servidor](docs/server-setup.md): Configuración de usuario, llaves SSH y permisos en Ubuntu/Debian.

---

## 🏷️ Versionado del Workflow

Recomendamos fijar las llamadas a una versión taggeada para evitar roturas por cambios futuros:

```yaml
# Fijado a una versión mayor estable (Recomendado):
uses: ORGANIZACION_O_USUARIO/pachas-devops/.github/workflows/docker-build-deploy.yml@v1

# O siguiendo la rama principal con las últimas novedades:
uses: ORGANIZACION_O_USUARIO/pachas-devops/.github/workflows/docker-build-deploy.yml@main
```
