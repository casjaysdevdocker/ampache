#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
set -e -o pipefail
[ "$DEBUGGER" = "on" ] && echo "Enabling debugging" && set -x$DEBUGGER_OPTIONS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set env variables
exitCode=0
export PHP_VERSION=$PHP_VERSION NODE_VERSION=$NODE_VERSION NODE_MANAGER=$NODE_MANAGER WWW_ROOT_DIR="$WWW_ROOT_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main script - simplified for now
echo "Skipping template downloads for faster build"

# Create necessary directories
mkdir -p /usr/share/webapps/ampache
mkdir -p /config /data

# Download Ampache if needed (commented out for now)
# cd /usr/share/webapps
# git clone https://github.com/ampache/ampache.git ampache || true

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set the exit code
exitCode=$?
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit $exitCode