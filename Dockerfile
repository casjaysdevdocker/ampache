FROM casjaysdevdocker/nginx:latest as build

WORKDIR /var/www/ampache

ARG LICENSE=WTFPL \
  IMAGE_NAME=ampache \
  TIMEZONE=America/New_York \
  PORT=80 \
  AMPACHE_VERSION=5.5.2

ENV SHELL=/bin/bash \
  TERM=xterm-256color \
  HOSTNAME=${HOSTNAME:-casjaysdev-$IMAGE_NAME} \
  TZ=$TIMEZONE

RUN mkdir -p /bin/ /config/ /data/ /var/lib/mysql && \
  rm -Rf /bin/.gitkeep /config/.gitkeep /data/.gitkeep && \
  apk update -U --no-cache && \
  apk add --no-cache unzip mariadb flac && \
  wget -nv "https://github.com/ampache/ampache/releases/download/${AMPACHE_VERSION}/ampache-${AMPACHE_VERSION}_all.zip" -O "/tmp/ampache.zip" && \
  unzip -q "/tmp/ampache.zip" -d "/var/www/ampache"

COPY ./bin/. /usr/local/bin/
COPY ./config/. /config/
COPY ./data/. /data/

FROM scratch
ARG BUILD_DATE="$(date +'%Y-%m-%d %H:%M')"

LABEL org.label-schema.name="ampache" \
  org.label-schema.description="Containerized version of ampache" \
  org.label-schema.url="https://hub.docker.com/r/casjaysdevdocker/ampache" \
  org.label-schema.vcs-url="https://github.com/casjaysdevdocker/ampache" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version=$BUILD_DATE \
  org.label-schema.vcs-ref=$BUILD_DATE \
  org.label-schema.license="$LICENSE" \
  org.label-schema.vcs-type="Git" \
  org.label-schema.schema-version="latest" \
  org.label-schema.vendor="CasjaysDev" \
  maintainer="CasjaysDev <docker-admin@casjaysdev.com>"

ENV SHELL="/bin/bash" \
  TERM="xterm-256color" \
  HOSTNAME="casjaysdev-ampache" \
  TZ="${TZ:-America/New_York}"

WORKDIR /root

VOLUME ["/root","/config","/data"]

EXPOSE $PORT

COPY --from=build /. /

ENTRYPOINT [ "tini", "--" ]
HEALTHCHECK --interval=15s --timeout=3s CMD [ "/usr/local/bin/entrypoint-ampache.sh", "healthcheck" ]
CMD [ "/usr/local/bin/entrypoint-ampache.sh" ]
