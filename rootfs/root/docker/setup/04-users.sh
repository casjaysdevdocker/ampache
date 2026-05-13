#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# casjaysdevdocker/ampache - 04-users.sh
# Defensive user/group creation. The Alpine apache2 and mariadb packages
# normally create their service users, but we ensure here.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -o pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS

exitCode=0

if ! getent group apache >/dev/null 2>&1; then
  addgroup -S apache 2>/dev/null || true
fi
if ! getent passwd apache >/dev/null 2>&1; then
  adduser -S -G apache -h /var/www -s /sbin/nologin apache 2>/dev/null || true
fi

if ! getent group mysql >/dev/null 2>&1; then
  addgroup -S mysql 2>/dev/null || true
fi
if ! getent passwd mysql >/dev/null 2>&1; then
  adduser -S -G mysql -h /data/db/mariadb -s /sbin/nologin mysql 2>/dev/null || true
fi

exit $exitCode
