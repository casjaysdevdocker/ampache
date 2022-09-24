## 👋 Welcome to ampache 🚀  

ampache README  
  
  
## Run container

```shell
dockermgr update ampache
```

### via command line

```shell
docker pull casjaysdevdocker/ampache:latest && \
docker run -d \
--restart always \
--name casjaysdevdocker-ampache \
--hostname casjaysdev-ampache \
-e TZ=${TIMEZONE:-America/New_York} \
-v $HOME/.local/share/docker/storage/ampache/ampache/data:/data \
-v $HOME/.local/share/docker/storage/ampache/ampache/config:/config \
-p 80:80 \
casjaysdevdocker/ampache:latest
```

### via docker-compose

```yaml
version: "2"
services:
  ampache:
    image: casjaysdevdocker/ampache
    container_name: ampache
    environment:
      - TZ=America/New_York
      - HOSTNAME=casjaysdev-ampache
    volumes:
      - $HOME/.local/share/docker/storage/ampache/data:/data:z
      - $HOME/.local/share/docker/storage/ampache/config:/config:z
    ports:
      - 80:80
    restart: always
```

## Authors  

🤖 casjay: [Github](https://github.com/casjay) [Docker](https://hub.docker.com/r/casjay) 🤖  
⛵ CasjaysDevdDocker: [Github](https://github.com/casjaysdev) [Docker](https://hub.docker.com/r/casjaysdevdocker) ⛵  
