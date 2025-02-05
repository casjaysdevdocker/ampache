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
export PHP_VERSION=$PHP_VERSION NODE_VERSION=$NODE_VERSION NODE_MANAGER=$NODE_MANAGER WWW_ROOT_DIR="$WWW_ROOT_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Predefined actions

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/php/raw/main/install.sh" || exit 1)"
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/mariadb/raw/main/install.sh" || exit 1)"
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/apache2/raw/main/install.sh" || exit 1)"
bash -c "$(curl -q -LSsf "https://github.com/templatemgr/ampache/raw/main/install.sh" || exit 1)"
bash -c "$(curl -q -LSsf "https://github.com/casjay-templates/default-html-pages/raw/main/install.sh" || exit 1)"
bash -c "$(curl -q -LSsf "https://github.com/casjay-templates/default-cgi-bin/raw/main/install.sh" || exit 1)"
bash -c "$(curl -q -LSsf "https://github.com/casjay-templates/default-error-pages/raw/main/install.sh" || exit 1)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
#exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit $exitCode
