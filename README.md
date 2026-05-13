## 👋 Welcome to ampache 🚀  

ampache README  
  
  
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
