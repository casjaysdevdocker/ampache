#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202502050828-git
# @@Author           :  CasjaysDev
# @@Contact          :  CasjaysDev <docker-admin@casjaysdev.pro>
# @@License          :  MIT
# @@ReadME           :
# @@Copyright        :  Copyright 2023 CasjaysDev
# @@Created          :  Mon Aug 28 06:48:42 PM EDT 2023
# @@File             :  05-custom.sh
# @@Description      :  script to run custom
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck shell=bash
# shellcheck disable=SC2016
# shellcheck disable=SC2031
# shellcheck disable=SC2120
# shellcheck disable=SC2155
# shellcheck disable=SC2199
# shellcheck disable=SC2317
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
set -o pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set env variables
exitCode=0
AMPACHE_TEMP_FILE="/tmp/ampache.zip"
AMPACHE_PHP_VER="${AMPACHE_PHP_VER:-8.4}"
AMPACHE_HOME="/usr/share/webapps/ampache"
AMPACHE_VERSION="${AMPACHE_VERSION:-1.3.9}"
AMPACHE_LASTEST="$(curl -q -LSsf "https://api.github.com/repos/ampache/ampache/releases" | jq -rc '.[].tag_name' | sort -rV | head -n1 | grep '^' || false)"
AMPACHE_ARCHIVE_FILE="https://github.com/ampache/ampache/releases/download/${AMPACHE_LASTEST:-$AMPACHE_VERSION}/ampache-${AMPACHE_LASTEST:-$AMPACHE_VERSION}_all_php${AMPACHE_PHP_VER}.zip"
export AMPACHE_HOME AMPACHE_VERSION AMPACHE_FILENAME="$(basename "$AMPACHE_ARCHIVE_FILE")" AMPACHE_RELEASE="$AMPACHE_LASTEST" PHP_VERSION=$PHP_VERSION NODE_VERSION=$NODE_VERSION NODE_MANAGER=$NODE_MANAGER WWW_ROOT_DIR="$WWW_ROOT_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Predefined actions

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/php/raw/main/install.sh")"
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/mariadb/raw/main/install.sh")"
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/apache2/raw/main/install.sh")"
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/ampache/raw/main/install.sh")"
bash -c "$(curl -q -LSsf "https://github.com/casjay-templates/default-html-pages/raw/main/install.sh")"
bash -c "$(curl -q -LSsf "https://github.com/casjay-templates/default-cgi-bin/raw/main/install.sh")"
bash -c "$(curl -q -LSsf "https://github.com/casjay-templates/default-error-pages/raw/main/install.sh")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
#exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit $exitCode
