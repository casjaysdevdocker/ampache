## 👋 Welcome to ampache 🚀  

A self-contained Docker image for [Ampache](https://ampache.org/), the open-source web-based music streaming server. Bundles Apache 2, PHP 8.4 via PHP-FPM, MariaDB, and Ampache itself. First run opens the Ampache web installer at `http://localhost:80/`.
  
  
## Install my system scripts  

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts  
```
  
## Automatic install/update  
  
```shell
dockermgr update ampache
```
  
## Install and run container
  
```shell
dockerHome="/var/lib/srv/$USER/docker/casjaysdevdocker/ampache/ampache/latest/rootfs"
mkdir -p "/var/lib/srv/$USER/docker/ampache/rootfs"
git clone "https://github.com/dockermgr/ampache" "$HOME/.local/share/CasjaysDev/dockermgr/ampache"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/ampache/rootfs/." "$dockerHome/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-ampache-latest \
--hostname ampache \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$dockerHome/data:/data:z" \
-v "$dockerHome/config:/config:z" \
-p 80:80 \
casjaysdevdocker/ampache:latest
```
  
## via docker-compose  
  
```yaml
version: "2"
services:
  ProjectName:
    image: casjaysdevdocker/ampache
    container_name: casjaysdevdocker-ampache
    environment:
      - TZ=America/New_York
      - HOSTNAME=ampache
    volumes:
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/ampache/ampache/latest/rootfs/data:/data:z"
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/ampache/ampache/latest/rootfs/config:/config:z"
    ports:
      - 80:80
    restart: always
```
  
## Environment variables  

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/New_York` | Container timezone (sets PHP date.timezone) |
| `MARIADB_ROOT_USER_NAME` | `root` | MariaDB root username |
| `MARIADB_ROOT_PASS_WORD` | `random` | MariaDB root password (auto-generated if `random`) |
| `MARIADB_USER_NAME` | `ampache` | MariaDB application username |
| `MARIADB_USER_PASS_WORD` | `random` | MariaDB application password (auto-generated if `random`) |
| `DATABASE_CREATE` | `ampache` | MariaDB database name to create |
| `HOSTNAME` | `ampache` | Container hostname used in Apache vhost |
| `DEBUGGER` | _(unset)_ | Set to `on` to enable bash `set -x` debugging |

Passwords generated on first run are saved to `/config/secure/auth/`.
  
## Volumes  

| Path | Purpose |
|------|---------|
| `/config` | All user-editable config files (Apache 2, PHP 8.4, MariaDB, Ampache) |
| `/data` | MariaDB data (`/data/db/mariadb`), logs (`/data/logs/`), and media library |

## Ports  

| Port | Protocol | Description |
|------|----------|-------------|
| `80` | HTTP | Ampache web UI and API |
| `443` | HTTPS | Available when SSL is enabled via `/config/enable/ssl` |

## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/ampache
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/ampache" "$HOME/Projects/github/casjaysdevdocker/ampache"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/ampache"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  
