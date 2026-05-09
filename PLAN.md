# ampache migration plan

## Service intent

Self-hosted music streaming server. Single Alpine-based Docker image bundling Apache (httpd) + PHP-FPM (php84) + MariaDB-server + the Ampache web app at `/usr/local/share/ampache`. Apache serves the app's `public/` subfolder (the canonical Ampache web root since v5+). Container exposes `:80`; first run takes the user to `install.php` which provisions the database and creates an admin account. Volumes: `/config` (user-editable settings: ampache config, httpd conf snippets, php-fpm pool, my.cnf, secure/auth) and `/data` (mariadb datadir, logs, uploaded media library if mounted there).

## Service stack

- Web server: `apache2` (Alpine) -> `/usr/sbin/httpd`, main config `/etc/apache2/httpd.conf`, vhost include in `/etc/apache2/conf.d/*.conf`. Uses event MPM, mod_rewrite + AllowOverride All for the Ampache `.htaccess`.
- App runtime: `php84-fpm` (Alpine) -> `/usr/sbin/php-fpm84`, conf `/etc/php84/php-fpm.conf` + pool `/etc/php84/php-fpm.d/www.conf`. Apache talks to it via `proxy_fcgi` over a unix socket `/run/php-fpm/php-fpm.sock` (no exposed TCP).
- Database: `mariadb` + `mariadb-client` (Alpine) -> `/usr/bin/mariadbd`, datadir `/data/db/mariadb`, socket `/run/mysqld/mysqld.sock`. Started by a separate `09-mariadb.sh` so it's up before ampache is rendered.
- Application: Ampache 7.9.3 (`ampache-7.9.3_all_php8.4.zip` from upstream GitHub releases — pre-built, vendor/ + node_modules/ already populated, no composer/npm needed at build time). Installed at `/usr/local/share/ampache`; Apache `DocumentRoot` is `/usr/local/share/ampache/public`.

## Packages (PACK_LIST / ENV_PACKAGES)

Trimmed from the original kitchen-sink list in the existing Dockerfile. Each package is on `pkgs.alpinelinux.org` (verified for the `edge` branch).

System glue:
- `bash`, `tini`, `curl`, `wget`, `unzip`, `tzdata`, `ca-certificates`, `pwgen` — entrypoint, fetching/extracting the ampache zip, password generation.
- `tar`, `gzip` — archive handling.

Apache:
- `apache2`, `apache2-ctl`, `apache2-utils` — server binary, control script, htpasswd/etc.
- `apache2-ssl` — mod_ssl (TLS support; off by default but available).
- `apache2-proxy` — mod_proxy + mod_proxy_fcgi (required to forward PHP requests to php-fpm).
- `apache2-http2` — http/2 support.
- `apache2-brotli` — mod_brotli compression.
- `apache2-icons`, `apache2-error` — icons + multilingual error pages.

(Dropped from prior list: `apache2-lua` `apache2-ldap` `apache2-webdav` `apache2-mod-wsgi` `apache-mod-fcgid` `apache2-proxy-html` — none are needed for ampache and `apache2-proxy` is the canonical fcgi backend, not `mod_fcgid`.)

PHP 8.4 — only the modules Ampache actually requires per upstream docs (PDO, PDO_MYSQL, hash, session, intl, json, curl, simplexml + optional gd, ldap, zip), plus FPM and the bare runtime:
- `php84` `php84-fpm` `php84-common` `php84-ctype` `php84-pdo` `php84-pdo_mysql` `php84-mysqli` `php84-mysqlnd` `php84-session` `php84-intl` `php84-curl` `php84-simplexml` `php84-xml` `php84-xmlreader` `php84-xmlwriter` `php84-dom` `php84-mbstring` `php84-iconv` `php84-tokenizer` `php84-fileinfo` `php84-openssl` `php84-phar` `php84-gd` `php84-zip` `php84-bz2` `php84-gmp` `php84-exif` `php84-opcache` `php84-pecl-redis`

(Dropped from prior list: dba, dev, doc, embed, enchant, ffi, ftp, gettext, imap, ldap (kept off — not needed by ampache out-of-box), litespeed, odbc, pcntl, pdo_dblib, pdo_odbc, pdo_pgsql, pdo_sqlite, pear, pgsql, phpdbg, posix, pspell, shmop, snmp, soap, sockets, sodium, sqlite3, sysvmsg, sysvsem, sysvshm, tidy, xsl, pecl-memcached, pecl-mcrypt, pecl-mongodb, calendar, cgi, bcmath. Kept what either a stock Ampache install touches or is part of ampache's bundled vendor extensions. `composer` is dropped — we use the prebuilt zip, no install step needed.)

MariaDB:
- `mariadb` — server (`/usr/bin/mariadbd`).
- `mariadb-client` — `mariadb` CLI client used by the post-execute initdb step.
- `mariadb-server-utils` — `mysql_install_db`, `mariadb-admin`, `mariadb-secure-installation`.

## Configs to ship in rootfs/tmp/etc/

Wipe-and-replace at build time (per template §4). All paths under `rootfs/tmp/etc/`.

- `apache2/httpd.conf` — minimal Alpine apache main config: load only the modules we need (mpm_event, mime, dir, alias, authz_core, authz_host, autoindex, deflate, brotli, expires, headers, log_config, mime_magic, negotiation, proxy, proxy_fcgi, rewrite, setenvif, ssl, status, unixd, http2). User/Group `apache:apache`. ServerRoot `/var/www`. Logs to `/data/logs/apache2/{access,error}.log`. PidFile `/run/apache2/httpd.pid`. ErrorLog/LogLevel sensible defaults. Final line: `IncludeOptional /etc/apache2/conf.d/*.conf` and `IncludeOptional /config/apache2/vhosts.d/*.conf` (optional, so empty dir doesn't crash).
- `apache2/conf.d/ampache.conf` — vhost: `<VirtualHost *:80>` with `DocumentRoot /usr/local/share/ampache/public`, `<Directory>` block (`Options FollowSymLinks`, `AllowOverride All`, `Require all granted`), `ProxyPassMatch ^/(.+\.php(/.*)?)$ unix:/run/php-fpm/php-fpm.sock|fcgi://localhost/usr/local/share/ampache/public/$1`, `DirectoryIndex index.php index.html`. Sets `SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1` (per upstream Apache vhost, needed for ampache API auth headers). ErrorLog/CustomLog under `/data/logs/apache2/`.
- `apache2/conf.d/mpm.conf` — switch to mpm_event explicitly + sane worker tunings.
- `php84/php.ini` — production-tuned: `memory_limit = 512M`, `upload_max_filesize = 256M`, `post_max_size = 256M`, `max_execution_time = 300`, `date.timezone = ${TZ}`, `expose_php = Off`, `cgi.fix_pathinfo = 0`, `opcache.enable = 1`, `opcache.memory_consumption = 256`, `opcache.max_accelerated_files = 20000`, `session.save_path = /tmp/php-sessions`.
- `php84/php-fpm.conf` — global: `pid = /run/php-fpm/php-fpm.pid`, `error_log = /data/logs/php-fpm/error.log`, `daemonize = no` (we run under our own supervisor), `include=/etc/php84/php-fpm.d/*.conf`.
- `php84/php-fpm.d/www.conf` — pool `[www]`, `user = apache`, `group = apache`, `listen = /run/php-fpm/php-fpm.sock`, `listen.owner = apache`, `listen.group = apache`, `listen.mode = 0660`, `pm = dynamic`, `pm.max_children = 20`, `pm.start_servers = 4`, `pm.min_spare_servers = 2`, `pm.max_spare_servers = 8`, `pm.max_requests = 500`, `clear_env = no`.
- `my.cnf.d/mariadb-server.cnf` — server config: `[mysqld]` with `datadir = /data/db/mariadb`, `socket = /run/mysqld/mysqld.sock`, `bind-address = 127.0.0.1` (DB only reachable inside container), `port = 3306`, `character-set-server = utf8mb4`, `collation-server = utf8mb4_unicode_ci`, `max_allowed_packet = 64M`, `innodb_buffer_pool_size = 256M`, `log_error = /data/logs/mariadb/mariadb.err.log`, `pid-file = /run/mysqld/mariadb.pid`. `[client]` `socket = /run/mysqld/mysqld.sock`. `[mysqld_safe]` matching log path.
- `ampache/ampache.cfg.php.dist` — empty placeholder (or a copy of the ampache-shipped dist file). Real `ampache.cfg.php` is generated by `install.php` on first web visit.

## /config/<svc>/ layout (user-editable)

The framework's `__initialize_system_etc` symlinks every file under `/config/<svc>/` back to its `/etc/<svc>/` peer. So our `/config/` seed (via `template-files/config/`) mirrors `/etc/` with the same paths:

- `/config/apache2/httpd.conf` -> symlinked to `/etc/apache2/httpd.conf`
- `/config/apache2/conf.d/ampache.conf` -> symlinked to `/etc/apache2/conf.d/ampache.conf`
- `/config/apache2/conf.d/mpm.conf` -> symlinked to `/etc/apache2/conf.d/mpm.conf`
- `/config/apache2/vhosts.d/*.conf` -> picked up by the `IncludeOptional` line for user-supplied vhosts
- `/config/php84/php.ini` -> `/etc/php84/php.ini`
- `/config/php84/php-fpm.conf` -> `/etc/php84/php-fpm.conf`
- `/config/php84/php-fpm.d/www.conf` -> `/etc/php84/php-fpm.d/www.conf`
- `/config/my.cnf.d/mariadb-server.cnf` -> `/etc/my.cnf.d/mariadb-server.cnf`
- `/config/ampache/ampache.cfg.php` -> bind-mounted into `/usr/local/share/ampache/config/ampache.cfg.php` (created post-install by `install.php`; we symlink the live file out to `/config/ampache/` after install completes so it survives container recreation).
- `/config/secure/auth/{root,user}/{ampache,mariadb}_{name,pass}` -> generated/used by the framework
- `/config/env/{ampache,mariadb}.sh` -> per-service env overrides

ADDITIONAL_CONFIG_DIRS for ampache will be `/config/apache2 /config/php84 /config/my.cnf.d /config/ampache` so each one runs through `__initialize_system_etc`.

## init.d/99-ampache.sh (and 09-mariadb.sh)

Two init.d scripts. MariaDB starts first (`09-`), Apache+PHP-FPM start under ampache (`99-`).

`rootfs/usr/local/etc/docker/init.d/09-mariadb.sh` — copy of mariadb repo's `09-mariadb.sh` with these knobs:
- `SERVICE_NAME="mariadb"`, `EXEC_CMD_BIN='mariadbd'`, `EXEC_CMD_ARGS='--user=$SERVICE_USER --datadir=$DATABASE_DIR --socket=/run/mysqld/mysqld.sock'`
- `SERVICE_USER="mysql"`, `SERVICE_GROUP="mysql"`
- `IS_DATABASE_SERVICE="yes"`, `DATABASE_SERVICE_TYPE="mariadb"`
- `__run_pre_execute_checks_local`: bootstrap datadir if missing (`mysql_install_db --datadir=$DATABASE_DIR --user=mysql`).
- `__post_execute_local`: when first run, create the `ampache` database + `ampache` user + grant; write password to `/config/secure/auth/user/ampache_db_pass`.

`rootfs/usr/local/etc/docker/init.d/99-ampache.sh` — based on nginx's 99-nginx.sh structure:
- `SERVICE_NAME="ampache"`, `SERVICE_USER="apache"`, `SERVICE_GROUP="apache"`
- `EXEC_CMD_BIN='httpd'`, `EXEC_CMD_ARGS='-D FOREGROUND -f /etc/apache2/httpd.conf'`
- `EXEC_PRE_SCRIPT='/usr/sbin/php-fpm84'` — start php-fpm as the pre-script (it reads `/etc/php84/php-fpm.conf` with `daemonize=no` but we run it before httpd; the framework's EXEC_PRE_SCRIPT pattern handles this).
- `IS_WEB_SERVER="yes"`, `USES_DATABASE_SERVICE="yes"`, `DATABASE_SERVICE_TYPE="mariadb"`
- `WWW_ROOT_DIR="/usr/local/share/ampache/public"`, `ETC_DIR="/etc/apache2"`, `CONF_DIR="/config/apache2"`
- `ADDITIONAL_CONFIG_DIRS="/config/php84 /config/my.cnf.d /config/ampache"`
- `SERVICE_PORT="80"`
- `__execute_prerun_local`: ensure runtime dirs (`/run/apache2`, `/run/php-fpm`, `/run/mysqld`, `/tmp/php-sessions`, `/data/logs/{apache2,php-fpm,mariadb,ampache}`) exist with right ownership; chown `/usr/local/share/ampache/{config,channel,rest,play}` to `apache:apache` for the install.php writes; symlink `/usr/local/share/ampache/config/ampache.cfg.php` -> `/config/ampache/ampache.cfg.php` if not present.
- `__pre_execute_local`: wait for mariadb socket to appear (`/run/mysqld/mysqld.sock`) up to 30s before starting apache.
- `__update_conf_files_local`: replace `REPLACE_TZ` token in `/etc/php84/php.ini` with `$TZ`. (No tokens in apache or my.cnf — paths are baked in.)

## 05-custom.sh additions

Replace the current placeholder content (which only `mkdir`s and creates an empty webapp dir) with:

1. Wipe distro-default `/etc/{apache2,php84,my.cnf.d}/*` (drop conf.d/{default,info,languages,mpm,userdir}.conf, ssl.conf etc.) so only our shipped files remain after `cp -Rf /tmp/etc/...`.
   ```sh
   for d in apache2 php84 my.cnf.d; do
     [ -d /tmp/etc/$d ] || continue
     rm -Rf /etc/$d/*
     cp -Rf /tmp/etc/$d/. /etc/$d/
   done
   ```
2. Fetch + install Ampache 7.9.3 prebuilt zip:
   ```sh
   AMPACHE_VERSION="7.9.3"
   AMPACHE_URL="https://github.com/ampache/ampache/releases/download/${AMPACHE_VERSION}/ampache-${AMPACHE_VERSION}_all_php8.4.zip"
   mkdir -p /usr/local/share/ampache
   cd /tmp
   wget -q -O /tmp/ampache.zip "$AMPACHE_URL"
   unzip -q /tmp/ampache.zip -d /usr/local/share/ampache
   rm -f /tmp/ampache.zip
   chown -R apache:apache /usr/local/share/ampache
   # ensure config dir exists for install.php to drop ampache.cfg.php
   mkdir -p /usr/local/share/ampache/config
   chown apache:apache /usr/local/share/ampache/config
   ```
3. Create runtime dirs needed by apache/php-fpm/mariadb so the first start doesn't trip on missing parents:
   ```sh
   mkdir -p /run/apache2 /run/php-fpm /run/mysqld /var/log/apache2 /tmp/php-sessions
   ```
4. Stage seed `template-files/config/ampache/` with an empty `.gitkeep` so `__initialize_config_dir` creates `/config/ampache/` on first run (the real `ampache.cfg.php` is written by install.php).

## 04-users.sh additions

The `mariadb` Alpine package creates the `mysql` user automatically; the `apache2` package creates `apache`. So 04-users.sh stays mostly empty — but add a defensive `addgroup -S apache 2>/dev/null; adduser -S -G apache -h /var/www -s /sbin/nologin apache 2>/dev/null` block in case package ordering doesn't guarantee them.

## 02-packages.sh additions

Empty (no per-package compile or pip step needed; the prebuilt ampache zip has all PHP deps inside `vendor/`).

## Dockerfile changes

- Update `BUILD_DATE` to `202605091200` (today, 2026-05-09 12:00).
- Replace `PACK_LIST` with the trimmed list above.
- Keep everything else (multi-stage, scratch final, ARGs, ENVs, volumes, healthcheck).
- No structural changes — the template's RUN steps already invoke 00–07 setup scripts in order.

## .env.scripts changes

- Sync `ENV_PACKAGES` to match the new `PACK_LIST` (single space separated, no double spaces).
- Leave `SERVICE_PORT="80"`, `EXPOSE_PORTS=""`, `PHP_VERSION="php84"`.

## README updates

Document the first-run workflow: visit `http://localhost:8080/` → ampache installer → fill in DB host `127.0.0.1`, user `ampache`, password from `/config/secure/auth/user/ampache_db_pass` (or read from `docker exec`), DB name `ampache` (already created by post-execute), web admin → enter desired admin user/email/pass → done. Note the volumes (`/config`, `/data`) and the music library mount pattern (`-v /path/to/music:/media:ro`).

## Verification (success criteria)

1. `cd /root/Projects/github/casjaysdevdocker/ampache && rm -f .build_failed && buildx run Dockerfile` succeeds for both `linux/amd64` and `linux/arm64`. Single retry permitted on transient network errors.
2. `docker run -d --rm --name test-ampache -p 18080:80 docker.io/casjaysdevdocker/ampache:latest` boots; after ~60s, `docker logs test-ampache | tail -50` shows no fatal errors and shows mariadb + php-fpm + httpd all started (look for "ready for connections", "fpm is running", "Apache/2... configured -- resuming normal operations").
3. `curl -fsS -o /dev/null -w '%{http_code}' http://localhost:18080/` returns 200 or 302 (the install.php redirect).
4. `docker exec test-ampache ls /config/ampache/ /config/apache2/ /config/php84/ /data/db/mariadb/ /usr/local/share/ampache/public/index.php` — every path exists.
5. `docker exec test-ampache mariadb -u root -e 'SHOW DATABASES;'` lists `ampache`.
6. `docker stop test-ampache`.

## Rollback

If anything in this PLAN.md proves wrong, the existing files are recoverable from git (`git checkout -- rootfs/`). New files (init.d, tmp/etc) can be removed cleanly because they didn't exist before.
