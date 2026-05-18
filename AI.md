# How this image is built and wired

## Base image and tooling

Built from `casjaysdev/alpine:latest` via a multi-stage Dockerfile (build stage → `FROM scratch` final). `tini` is the PID 1 supervisor; `gosu` provides privilege dropping. Package management is handled by `pkmgr` (auto-detects `apk`).

## Package set

All packages come from Alpine's `apk` package manager. Key groups:

- **Apache 2**: `apache2 apache2-ctl apache2-utils apache2-ssl apache2-proxy apache2-http2 apache2-brotli apache2-icons apache2-error`
- **PHP 8.4**: `php84 php84-fpm` plus all modules Ampache requires (pdo, pdo_mysql, mysqli, mysqlnd, session, intl, curl, simplexml, xml, xmlreader, xmlwriter, dom, mbstring, iconv, tokenizer, fileinfo, openssl, phar, gd, zip, bz2, gmp, exif, opcache, pecl-redis, ctype)
- **MariaDB**: `mariadb mariadb-client mariadb-server-utils`
- **Utilities**: `bash tini curl wget unzip tar gzip tzdata ca-certificates pwgen`

## Build-time setup flow (`rootfs/root/docker/setup/`)

| Script | Role |
|--------|------|
| `00-init.sh` | Clears `template-files/{data,config,defaults}` staging dirs |
| `01-system.sh` | Stub (Alpine repos are already configured by the base image) |
| `02-packages.sh` | Stub (no post-install compile steps; prebuilt Ampache zip needs no composer/npm) |
| `03-files.sh` | Auto-installs `rootfs/tmp/etc/*` → `/etc/*` and stages copies under `template-files/config/` |
| `04-users.sh` | Defensive creation of `apache:apache` and `mysql:mysql` system accounts |
| `05-custom.sh` | **Core setup**: wipes distro defaults under `/etc/{apache2,php84,my.cnf.d}/*`, copies our optimized configs from `/tmp/etc/`, then downloads and unpacks the Ampache prebuilt zip to `/usr/local/share/ampache/` |
| `06-post.sh` | Stub |
| `07-cleanup.sh` | Stub |

## Config wipe-and-replace

`05-custom.sh` performs the canonical wipe-and-replace for all three config trees:

1. Preserve `apache2/mime.types` and `apache2/magic` (not shipped in our `rootfs/tmp/etc/apache2/`)
2. `rm -Rf /etc/{apache2,php84,my.cnf.d}/*`
3. `cp -Rf /tmp/etc/{apache2,php84,my.cnf.d}/. /etc/{apache2,php84,my.cnf.d}/`
4. Copy resulting `/etc/` trees to `template-files/config/` for runtime seeding

## Runtime init.d scripts

Two init.d scripts run in numeric order:

### `09-mariadb.sh`
- `SERVICE_NAME="mariadb"`, `EXEC_CMD_BIN='mariadbd'`
- Runs as `mysql:mysql`; datadir `/data/db/mariadb`; socket `/run/mysqld/mysqld.sock`
- `IS_DATABASE_SERVICE="yes"`, `DATABASE_SERVICE_TYPE="mariadb"`
- `__run_pre_execute_checks`: initializes the datadir with `mariadb-install-db` if `ibdata1` is missing
- `__post_execute`: waits for the socket, then creates the `ampache` database, `ampache` user (random password), grants privileges, and sets the root password

### `99-ampache.sh`
- `SERVICE_NAME="ampache"`, `EXEC_CMD_BIN='/usr/local/etc/docker/bin/start-ampache'`
- `IS_WEB_SERVER="yes"`, `USES_DATABASE_SERVICE="yes"`, `DATABASE_SERVICE_TYPE="mariadb"`
- `SERVICE_USER="apache"`, `SERVICE_GROUP="apache"`
- `WWW_ROOT_DIR="/usr/local/share/ampache/public"`, `ETC_DIR="/etc/apache2"`, `CONF_DIR="/config/apache2"`
- `ADDITIONAL_CONFIG_DIRS="/config/php84 /config/ampache"`
- `__execute_prerun`: creates runtime dirs (`/run/apache2 /run/php-fpm /tmp/php-sessions /data/logs/{apache2,php-fpm}`), chowns them to `apache:apache`; symlinks `ampache.cfg.php` between `/usr/local/share/ampache/config/` and `/config/ampache/` once install.php writes it
- `__run_pre_execute_checks`: waits up to 30 s for the MariaDB socket; validates `httpd -t` apache config syntax
- `__update_conf_files`: replaces the `REPLACE_TZ` token in `/etc/php84/php.ini` with `$TZ`
- `__post_execute`: mirrors `ampache.cfg.php` out to `/config/ampache/` and creates the symlink if install.php has written it

### `start-ampache` wrapper
`EXEC_CMD_BIN` points to `/usr/local/etc/docker/bin/start-ampache`, which:
1. Starts `php-fpm84` in the background (waits up to 10 s for `/run/php-fpm/php-fpm.sock`)
2. Exec's `httpd -D FOREGROUND -f /etc/apache2/httpd.conf` (becomes the process the framework monitors)

## Config paths

| Component | Config file | User-editable at |
|-----------|-------------|-----------------|
| Apache main | `/etc/apache2/httpd.conf` | `/config/apache2/httpd.conf` |
| Apache ampache vhost | `/etc/apache2/conf.d/ampache.conf` | `/config/apache2/conf.d/ampache.conf` |
| Apache MPM tuning | `/etc/apache2/conf.d/mpm.conf` | `/config/apache2/conf.d/mpm.conf` |
| User vhosts | `IncludeOptional /config/apache2/vhosts.d/*.conf` | `/config/apache2/vhosts.d/` |
| PHP runtime | `/etc/php84/php.ini` | `/config/php84/php.ini` |
| PHP-FPM global | `/etc/php84/php-fpm.conf` | `/config/php84/php-fpm.conf` |
| PHP-FPM pool | `/etc/php84/php-fpm.d/www.conf` | `/config/php84/php-fpm.d/www.conf` |
| MariaDB server | `/etc/my.cnf.d/mariadb-server.cnf` | `/config/my.cnf.d/mariadb-server.cnf` |
| Ampache app config | `/usr/local/share/ampache/config/ampache.cfg.php` | `/config/ampache/ampache.cfg.php` (symlinked) |

## Volume layout

- `/config` — all user-editable configs (seeded on first run from `template-files/config/`)
- `/data` — MariaDB datadir (`/data/db/mariadb`), logs (`/data/logs/`), media library if mounted

## Port

- `80` (HTTP); `443` available if SSL is enabled via `/config/enable/ssl`
