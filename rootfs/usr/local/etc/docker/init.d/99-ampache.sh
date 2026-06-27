#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202606261600-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  99-ampache.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Wednesday, May 13, 2026 14:34 EDT
# @@File             :  99-ampache.sh
# @@Description      :  apache + php-fpm init.d script for casjaysdevdocker/ampache
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  other/start-service
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -e
# - - - - - - - - - - - - - - - - - - - - - - - - -
# run trap command on exit
trap '__trap_err_handler' ERR
trap 'retVal=$?;if [ "$SERVICE_IS_RUNNING" != "yes" ] && [ -f "$SERVICE_PID_FILE" ]; then rm -Rf "$SERVICE_PID_FILE"; fi;exit $retVal' SIGINT SIGTERM SIGPWR
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ERR trap handler - smart about critical vs non-critical errors
__trap_err_handler() {
  local retVal=$?
  local command="$BASH_COMMAND"
  # Ignore SIGPIPE and user interrupts
  [ $retVal -eq 130 ] || [ $retVal -eq 141 ] && return $retVal
  # Non-critical: file operations, text processing, user/group operations
  if [[ "$command" =~ (mkdir|touch|chmod|chown|chgrp|ln|cp|mv|rm|echo|printf|cat|tee|sed|awk|grep|find|sort|uniq|adduser|addgroup|usermod|groupmod|id|getent) ]]; then
    return 0
  fi
  # Non-critical: conditional checks that might fail
  if [[ "$command" =~ (test|\[|\[\[|kill -0|pgrep|pidof|ps) ]]; then
    return 0
  fi
  # Critical error - but only fail if service hasn't started yet
  if [ "$SERVICE_IS_RUNNING" != "yes" ]; then
    echo "❌ Critical error (exit $retVal): $command" >&2
    kill -TERM 1 2>/dev/null || exit $retVal
  fi
  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
SCRIPT_FILE="$0"
SERVICE_NAME="ampache"
SCRIPT_NAME="${SCRIPT_FILE##*/}"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Function to exit appropriately based on context
__script_exit() {
  local exit_code="${1:-0}"
  if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced - use return
    return "$exit_code"
  else
    # Script is being executed - use exit
    exit "$exit_code"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
# setup debugging - https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
[ -f "/config/.debug" ] && [ -z "$DEBUGGER_OPTIONS" ] && export DEBUGGER_OPTIONS="$(<"/config/.debug")" || DEBUGGER_OPTIONS="${DEBUGGER_OPTIONS:-}"
if [ "$DEBUGGER" = "on" ] || [ -f "/config/.debug" ]; then
  echo "Enabling debugging"
  set -xo pipefail -x$DEBUGGER_OPTIONS
  export DEBUGGER="on"
else
  set -o pipefail
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
export PATH="/usr/local/etc/docker/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# import the functions file
if [ -f "/usr/local/etc/docker/functions/entrypoint.sh" ]; then
  . "/usr/local/etc/docker/functions/entrypoint.sh"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
# import variables
for set_env in "/root/env.sh" "/usr/local/etc/docker/env"/*.sh "/config/env"/*.sh; do
  if [ -f "$set_env" ]; then
    . "$set_env"
  fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - -
# exit if __start_init_scripts function hasn't been Initialized
if [ ! -f "/run/.start_init_scripts.pid" ]; then
  echo "__start_init_scripts function hasn't been Initialized" >&2
  SERVICE_IS_RUNNING="no"
  __script_exit 1
fi
# Clean up any stale PID file for this service on startup
if [ -n "$SERVICE_NAME" ] && [ -f "/run/init.d/$SERVICE_NAME.pid" ]; then
  old_pid=$(<"/run/init.d/$SERVICE_NAME.pid") 2>/dev/null
  if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
    echo "Removing stale PID file for $SERVICE_NAME"
    rm -f "/run/init.d/$SERVICE_NAME.pid"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Script to execute
START_SCRIPT="/usr/local/etc/docker/exec/$SERVICE_NAME"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Reset environment before executing service
RESET_ENV="no"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Set webroot
WWW_ROOT_DIR="/usr/local/share/ampache/public"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Default predefined variables
DATA_DIR="/data/ampache"
CONF_DIR="/config/apache2"
ETC_DIR="/etc/apache2"
VAR_DIR=""
TMP_DIR="/tmp/ampache"
RUN_DIR="/run/apache2"
LOG_DIR="/data/logs/apache2"
WORK_DIR=""
# - - - - - - - - - - - - - - - - - - - - - - - - -
# port which service is listening on
SERVICE_PORT="80"
# - - - - - - - - - - - - - - - - - - - - - - - - -
RUNAS_USER="root"
SERVICE_USER="apache"
SERVICE_GROUP="apache"
# - - - - - - - - - - - - - - - - - - - - - - - - -
RANDOM_PASS_USER=""
RANDOM_PASS_ROOT=""
SERVICE_UID="0"
SERVICE_GID="0"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# execute command variables - keep single quotes; variables will be expanded later
EXEC_CMD_BIN='/usr/local/etc/docker/bin/start-ampache'
EXEC_CMD_ARGS=''
EXEC_PRE_SCRIPT=''
# Set to 'no' for configuration services (no daemon process), leave blank for actual services
SERVICE_USES_PID=''
# - - - - - - - - - - - - - - - - - - - - - - - - -
IS_WEB_SERVER="yes"
IS_DATABASE_SERVICE="no"
USES_DATABASE_SERVICE="yes"
DATABASE_SERVICE_TYPE="mariadb"
# - - - - - - - - - - - - - - - - - - - - - - - - -
PRE_EXEC_MESSAGE="Open http://localhost:${SERVICE_PORT:-80}/ to run the Ampache web installer."
POST_EXECUTE_WAIT_TIME="1"
# - - - - - - - - - - - - - - - - - - - - - - - - -
PATH="$PATH:."
# - - - - - - - - - - - - - - - - - - - - - - - - -
IP4_ADDRESS="$(__get_ip4)"
IP6_ADDRESS="$(__get_ip6)"
# - - - - - - - - - - - - - - - - - - - - - - - - -
ROOT_FILE_PREFIX="/config/secure/auth/root"
USER_FILE_PREFIX="/config/secure/auth/user"
# - - - - - - - - - - - - - - - - - - - - - - - - -
root_user_name="${AMPACHE_ROOT_USER_NAME:-}"
root_user_pass="${AMPACHE_ROOT_PASS_WORD:-}"
user_name="${AMPACHE_USER_NAME:-}"
user_pass="${AMPACHE_USER_PASS_WORD:-}"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Load variables from config
if [ -f "/config/env/ampache.script.sh" ]; then
  . "/config/env/ampache.script.sh"
fi
if [ -f "/config/env/ampache.sh" ]; then
  . "/config/env/ampache.sh"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
ADD_APPLICATION_FILES=""
ADD_APPLICATION_DIRS="/usr/local/share/ampache /usr/local/share/ampache/config /tmp/php-sessions"
APPLICATION_FILES="$LOG_DIR/$SERVICE_NAME.log"
APPLICATION_DIRS="$ETC_DIR $CONF_DIR $LOG_DIR $TMP_DIR $RUN_DIR $VAR_DIR /run/php-fpm /data/logs/php-fpm"
ADDITIONAL_CONFIG_DIRS="/config/php84 /config/ampache"
CMD_ENV=""
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Custom functions

# - - - - - - - - - - - - - - - - - - - - - - - - -
__run_precopy() {
  local hostname=${HOSTNAME}
  if [ ! -d "/run/healthcheck" ]; then
    mkdir -p "/run/healthcheck"
  fi
  if builtin type -t __run_precopy_local | grep -q 'function'; then
    __run_precopy_local
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__execute_prerun() {
  local hostname=${HOSTNAME}
  # Ensure runtime dirs
  mkdir -p /run/apache2 /run/php-fpm /tmp/php-sessions \
           /data/logs/apache2 /data/logs/php-fpm /data/ampache
  chown -Rf apache:apache /run/apache2 /run/php-fpm /tmp/php-sessions \
           /data/logs/apache2 /data/logs/php-fpm 2>/dev/null || true
  # Ampache writable dirs
  if [ -d /usr/local/share/ampache ]; then
    mkdir -p /usr/local/share/ampache/config
    chown -Rf apache:apache /usr/local/share/ampache/config 2>/dev/null || true
    # Live ampache.cfg.php is mirrored out to /config/ampache/ once install.php writes it.
    if [ -f /usr/local/share/ampache/config/ampache.cfg.php ] && [ ! -L /usr/local/share/ampache/config/ampache.cfg.php ]; then
      cp -f /usr/local/share/ampache/config/ampache.cfg.php /config/ampache/ampache.cfg.php 2>/dev/null || true
      ln -sf /config/ampache/ampache.cfg.php /usr/local/share/ampache/config/ampache.cfg.php
    elif [ -f /config/ampache/ampache.cfg.php ] && [ ! -e /usr/local/share/ampache/config/ampache.cfg.php ]; then
      ln -sf /config/ampache/ampache.cfg.php /usr/local/share/ampache/config/ampache.cfg.php
    fi
  fi
  if builtin type -t __execute_prerun_local | grep -q 'function'; then
    __execute_prerun_local
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__run_pre_execute_checks() {
  local exitStatus=0
  local pre_execute_checks_MessageST="Running preexecute check for $SERVICE_NAME"
  local pre_execute_checks_MessageEnd="Finished preexecute check for $SERVICE_NAME"
  __banner "$pre_execute_checks_MessageST"
  {
    # Wait briefly for mariadb socket
    local i=0
    while [ ! -S /run/mysqld/mysqld.sock ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
    if [ ! -S /run/mysqld/mysqld.sock ]; then
      echo "Warning: mariadb socket not found after 30s; ampache install.php will need it before continuing" >&2
    fi
    # Validate apache config syntax
    httpd -t -f /etc/apache2/httpd.conf 2>&1 | head -20 || exitStatus=$?
  }
  exitStatus=$?
  __banner "$pre_execute_checks_MessageEnd: Status $exitStatus"
  if [ $exitStatus -ne 0 ]; then
    echo "The pre-execution check has failed" >&2
    if [ -f "$SERVICE_PID_FILE" ]; then
      rm -Rf "$SERVICE_PID_FILE"
    fi
    __script_exit 1
  fi
  if builtin type -t __run_pre_execute_checks_local | grep -q 'function'; then
    __run_pre_execute_checks_local
  fi
  return $exitStatus
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__update_conf_files() {
  local exitCode=0
  local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
  __replace "REPLACE_TZ" "${TZ:-UTC}" "/etc/php84/php.ini"
  if builtin type -t __update_conf_files_local | grep -q 'function'; then
    __update_conf_files_local
  fi
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__pre_execute() {
  local exitCode=0
  local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
  unset sysname
  sleep 5
  if builtin type -t __pre_execute_local | grep -q 'function'; then
    __pre_execute_local
  fi
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__post_execute() {
  local pid=""
  local retVal=0
  local ctime=${POST_EXECUTE_WAIT_TIME:-1}
  local waitTime=$((ctime * 60))
  local postMessageST="Running post commands for $SERVICE_NAME"
  local postMessageEnd="Finished post commands for $SERVICE_NAME"
  sleep $waitTime
  (
    __banner "$postMessageST"
    # Mirror live ampache.cfg.php out to /config once install.php has written it
    if [ -f /usr/local/share/ampache/config/ampache.cfg.php ] && [ ! -L /usr/local/share/ampache/config/ampache.cfg.php ]; then
      cp -f /usr/local/share/ampache/config/ampache.cfg.php /config/ampache/ampache.cfg.php
      ln -sf /config/ampache/ampache.cfg.php /usr/local/share/ampache/config/ampache.cfg.php
    fi
    __banner "$postMessageEnd: Status $retVal"
  ) 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt" &
  pid=$!
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    retVal=0
  else
    retVal=10
  fi
  if builtin type -t __post_execute_local | grep -q 'function'; then
    __post_execute_local
  fi
  return $retVal
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__pre_message() {
  local exitCode=0
  if [ -n "$PRE_EXEC_MESSAGE" ]; then
    eval echo "$PRE_EXEC_MESSAGE"
  fi
  if builtin type -t __pre_message_local | grep -q 'function'; then
    __pre_message_local
  fi
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__update_ssl_conf() {
  local exitCode=0
  local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
  if builtin type -t __update_ssl_conf_local | grep -q 'function'; then
    __update_ssl_conf_local
  fi
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__create_service_env() {
  local exitCode=0
  if [ ! -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ]; then
    cat <<EOF | tee -p "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Generated by 99-ampache.sh - edit to override defaults
#user_name=""
#user_pass=""
EOF
  fi
  if [ ! -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" ]; then
  	cat <<'EOF' >"/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Local overrides - sourced after the main env file.
# Redefine any of these functions to customise behaviour.
# - - - - - - - - - - - - - - - - - - - - - - - - -
__run_precopy_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__execute_prerun_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__run_pre_execute_checks_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__update_conf_files_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__pre_execute_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__post_execute_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__pre_message_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
__update_ssl_conf_local() { true; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
EOF
  fi
  if ! __file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"; then
    exitCode=$((exitCode + 1))
  fi
  if ! __file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh"; then
    exitCode=$((exitCode + 1))
  fi
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__run_start_script() {
  local runExitCode=0
  local workdir="$(eval echo "${WORK_DIR:-}")"
  local cmd="$(eval echo "${EXEC_CMD_BIN:-}")"
  local args="$(eval echo "${EXEC_CMD_ARGS:-}")"
  local name="$(eval echo "${EXEC_CMD_NAME:-}")"
  local pre="$(eval echo "${EXEC_PRE_SCRIPT:-}")"
  local extra_env="$(eval echo "${CMD_ENV//,/ }")"
  local lc_type="$(eval echo "${LANG:-${LC_ALL:-$LC_CTYPE}}")"
  local home="$(eval echo "${workdir//\/root/\/tmp\/docker}")"
  local path="$(eval echo "$PATH")"
  local message="$(eval echo "")"
  local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
  if [ -f "$CONF_DIR/$SERVICE_NAME.exec_cmd.sh" ]; then
    . "$CONF_DIR/$SERVICE_NAME.exec_cmd.sh"
  fi
  if [ -z "$cmd" ]; then
    __post_execute 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt"
    retVal=$?
    __log_info "Initialization of $SCRIPT_NAME has completed"
    __script_exit $retVal
  else
    if [ ! -x "$cmd" ]; then
      __log_error "$name is not a valid executable"
      return 2
    fi
    if __proc_check "$name" || __proc_check "$cmd"; then
      __log_debug "Service $name is already running"
      return 0
    else
      if [ -n "$cmd" ]; then
        if [ -n "$SERVICE_USER" ]; then
          __log_info "Setting up $cmd to run as $SERVICE_USER"
        else
          SERVICE_USER="root"
        fi
        if [ -n "$SERVICE_PORT" ]; then
          __log_info "$name will be running on port $SERVICE_PORT"
        else
          SERVICE_PORT=""
        fi
      fi
      if [ -n "$pre" ] && command -v "$pre" &>/dev/null; then
        export cmd_exec="$pre $cmd $args"
        message="Starting service: $name $args through $pre"
      else
        export cmd_exec="$cmd $args"
        message="Starting service: $name $args"
      fi
      if [ -n "$su_exec" ]; then
        __log_debug "Using $su_exec" | tee -a -p "/data/logs/init.txt"
      fi
      __log_info "$message" | tee -a -p "/data/logs/init.txt"
      su_cmd touch "$SERVICE_PID_FILE"
      if [ "$RESET_ENV" = "yes" ]; then
        env_command="$(echo "env -i HOME=\"$home\" LC_CTYPE=\"$lc_type\" PATH=\"$path\" HOSTNAME=\"$sysname\" USER=\"${SERVICE_USER:-$RUNAS_USER}\" $extra_env")"
        execute_command="$(__trim "$su_exec $env_command $cmd_exec")"
        if [ ! -f "$START_SCRIPT" ]; then
          cat <<EOF >"$START_SCRIPT"
#!/usr/bin/env bash
trap 'exitCode=\$?;[ \$exitCode -ne 0 ] && [ -f "\$SERVICE_PID_FILE" ] && rm -Rf "\$SERVICE_PID_FILE";exit \$exitCode' EXIT
#
set -Eeo pipefail
# Setting up $cmd to run as ${SERVICE_USER:-root} with env
retVal=10
cmd="$cmd"
args="$args"
SERVICE_NAME="$SERVICE_NAME"
SERVICE_PID_FILE="$SERVICE_PID_FILE"
LOG_DIR="$LOG_DIR"
execute_command="$execute_command"
\$execute_command 2>"/dev/stderr" >>"\$LOG_DIR/\$SERVICE_NAME.log" &
execPid=\$!
sleep 1
if [ -n "\$execPid" ] && kill -0 "\$execPid" 2>/dev/null; then
  echo "\$execPid" >"\$SERVICE_PID_FILE"
  retVal=0
  printf '%s\n' "\$SERVICE_NAME: \$execPid" >"/run/healthcheck/\$SERVICE_NAME"
else
  retVal=10
  echo "Failed to start $execute_command" >&2
fi
exit \$retVal

EOF
        fi
      else
        if [ ! -f "$START_SCRIPT" ]; then
          execute_command="$(__trim "$su_exec $cmd_exec")"
          cat <<EOF >"$START_SCRIPT"
#!/usr/bin/env bash
trap 'exitCode=\$?;[ \$exitCode -ne 0 ] && [ -f "\$SERVICE_PID_FILE" ] && rm -Rf "\$SERVICE_PID_FILE";exit \$exitCode' EXIT
#
set -Eeo pipefail
# Setting up $cmd to run as ${SERVICE_USER:-root}
retVal=10
cmd="$cmd"
args="$args"
SERVICE_NAME="$SERVICE_NAME"
SERVICE_PID_FILE="$SERVICE_PID_FILE"
LOG_DIR="$LOG_DIR"
execute_command="$execute_command"
\$execute_command 2>>"/dev/stderr" >>"\$LOG_DIR/\$SERVICE_NAME.log" &
execPid=\$!
sleep 1
if [ -n "\$execPid" ] && kill -0 "\$execPid" 2>/dev/null; then
  echo "\$execPid" >"\$SERVICE_PID_FILE"
  retVal=0
else
  retVal=10
  echo "Failed to start $execute_command" >&2
fi
exit \$retVal

EOF
        fi
      fi
    fi
    if [ ! -x "$START_SCRIPT" ]; then
      chmod 755 -Rf "$START_SCRIPT"
    fi
    if [ "$CONTAINER_INIT" != "yes" ]; then
      eval sh -c "$START_SCRIPT"
      runExitCode=$?
    fi
  fi
  return $runExitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__run_secure_function() {
  local filesperms
  if [ -n "$user_name" ] || [ -n "$user_pass" ]; then
    for filesperms in "${USER_FILE_PREFIX}"/*; do
      if [ -e "$filesperms" ]; then
        chmod -Rf 600 "$filesperms"
        chown -Rf $SERVICE_USER:$SERVICE_USER "$filesperms" 2>/dev/null
      fi
    done 2>/dev/null | tee -p -a "/data/logs/init.txt"
  fi
  if [ -n "$root_user_name" ] || [ -n "$root_user_pass" ]; then
    for filesperms in "${ROOT_FILE_PREFIX}"/*; do
      if [ -e "$filesperms" ]; then
        chmod -Rf 600 "$filesperms"
        chown -Rf $SERVICE_USER:$SERVICE_USER "$filesperms" 2>/dev/null
      fi
    done 2>/dev/null | tee -p -a "/data/logs/init.txt"
  fi
  unset filesperms
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Allow ENV_ variable - Import env file
if __file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"; then
  . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
fi
if __file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh"; then
  . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
# default exit code
SERVICE_EXIT_CODE=0
# application specific
EXEC_CMD_NAME="${EXEC_CMD_BIN##*/}"
SERVICE_PID_FILE="/run/init.d/$EXEC_CMD_NAME.pid"
SERVICE_PID_NUMBER="$(__pgrep "$EXEC_CMD_NAME" 2>/dev/null || echo '')"
_resolved="$(type -P "$EXEC_CMD_BIN" 2>/dev/null)"
[ -n "$_resolved" ] && EXEC_CMD_BIN="$_resolved"
_resolved="$(type -P "$EXEC_PRE_SCRIPT" 2>/dev/null)"
[ -n "$_resolved" ] && EXEC_PRE_SCRIPT="$_resolved"
unset _resolved
# - - - - - - - - - - - - - - - - - - - - - - - - -
if __check_service "$1"; then
  SERVICE_IS_RUNNING=yes
else
  SERVICE_IS_RUNNING="no"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi
if [ ! -d "$RUN_DIR" ]; then
  mkdir -p "$RUN_DIR"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -n "$USER_FILE_PREFIX" ]; then
  if [ ! -d "$USER_FILE_PREFIX" ]; then
    mkdir -p "$USER_FILE_PREFIX"
  fi
fi
if [ -n "$ROOT_FILE_PREFIX" ]; then
  if [ ! -d "$ROOT_FILE_PREFIX" ]; then
    mkdir -p "$ROOT_FILE_PREFIX"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -z "$RUNAS_USER" ]; then
  RUNAS_USER="root"
fi
if [ -z "$SERVICE_USER" ]; then
  SERVICE_USER="$RUNAS_USER"
fi
if [ -z "$SERVICE_GROUP" ]; then
  SERVICE_GROUP="${SERVICE_USER:-$RUNAS_USER}"
fi
if [ "$IS_WEB_SERVER" = "yes" ]; then
  RESET_ENV="yes"
  __is_htdocs_mounted
fi
if [ "$IS_WEB_SERVER" = "yes" ] && [ -z "$SERVICE_PORT" ]; then
  SERVICE_PORT="80"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Database env
if [ "$IS_DATABASE_SERVICE" = "yes" ] || [ "$USES_DATABASE_SERVICE" = "yes" ]; then
  RESET_ENV="no"
  DATABASE_CREATE="${ENV_DATABASE_CREATE:-$DATABASE_CREATE}"
  DATABASE_USER_NORMAL="${ENV_DATABASE_USER:-${DATABASE_USER_NORMAL:-$user_name}}"
  DATABASE_PASS_NORMAL="${ENV_DATABASE_PASSWORD:-${DATABASE_PASS_NORMAL:-$user_pass}}"
  DATABASE_USER_ROOT="${ENV_DATABASE_ROOT_USER:-${DATABASE_USER_ROOT:-$root_user_name}}"
  DATABASE_PASS_ROOT="${ENV_DATABASE_ROOT_PASSWORD:-${DATABASE_PASS_ROOT:-$root_user_pass}}"
  if [ -n "$DATABASE_PASS_NORMAL" ]; then
    if [ ! -f "${USER_FILE_PREFIX}/db_pass_user" ]; then
      echo "$DATABASE_PASS_NORMAL" >"${USER_FILE_PREFIX}/db_pass_user"
    fi
  fi
  if [ -n "$DATABASE_PASS_ROOT" ]; then
    if [ ! -f "${ROOT_FILE_PREFIX}/db_pass_root" ]; then
      echo "$DATABASE_PASS_ROOT" >"${ROOT_FILE_PREFIX}/db_pass_root"
    fi
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
DATABASE_DIR="${DATABASE_DIR_MARIADB:-/data/db/mariadb}"
DATABASE_BASE_DIR="$DATABASE_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Allow variables via imports - Overwrite existing
if [ -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ]; then
  . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$user_pass" = "random" ]; then
  user_pass="$(__random_password ${RANDOM_PASS_USER:-16})"
fi
if [ "$root_user_pass" = "random" ]; then
  root_user_pass="$(__random_password ${RANDOM_PASS_ROOT:-16})"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -n "$user_name" ]; then
  echo "$user_name" >"${USER_FILE_PREFIX}/${SERVICE_NAME}_name"
fi
if [ -n "$user_pass" ]; then
  echo "$user_pass" >"${USER_FILE_PREFIX}/${SERVICE_NAME}_pass"
fi
if [ -n "$root_user_name" ]; then
  echo "$root_user_name" >"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_name"
fi
if [ -n "$root_user_pass" ]; then
  echo "$root_user_pass" >"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi
if [ ! -d "$RUN_DIR" ]; then
  mkdir -p "$RUN_DIR"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
if __file_exists_with_content "${USER_FILE_PREFIX}/${SERVICE_NAME}_name"; then
  user_name="$(<"${USER_FILE_PREFIX}/${SERVICE_NAME}_name")"
fi
if __file_exists_with_content "${USER_FILE_PREFIX}/${SERVICE_NAME}_pass"; then
  user_pass="$(<"${USER_FILE_PREFIX}/${SERVICE_NAME}_pass")"
fi
if __file_exists_with_content "${ROOT_FILE_PREFIX}/${SERVICE_NAME}_name"; then
  root_user_name="$(<"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_name")"
fi
if __file_exists_with_content "${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass"; then
  root_user_pass="$(<"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass")"
fi
if __file_exists_with_content "${USER_FILE_PREFIX}/db_pass_user"; then
  DATABASE_PASS_NORMAL="$(<"${USER_FILE_PREFIX}/db_pass_user")"
fi
if __file_exists_with_content "${ROOT_FILE_PREFIX}/db_pass_root"; then
  DATABASE_PASS_ROOT="$(<"${ROOT_FILE_PREFIX}/db_pass_root")"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
# - - - - - - - - - - - - - - - - - - - - - - - - -
__create_service_env
__init_config_etc
__execute_prerun
__create_service_user "$SERVICE_USER" "$SERVICE_GROUP" "${WORK_DIR:-/home/$SERVICE_USER}" "${SERVICE_UID:-}" "${SERVICE_GID:-}"
__set_user_group_id $SERVICE_USER ${SERVICE_UID:-} ${SERVICE_GID:-}
__setup_directories
__switch_to_user
__init_working_dir
__pre_message
__initialize_db_users
__update_ssl_conf
__update_ssl_certs
__run_secure_function
__run_precopy
for config_2_etc in $CONF_DIR $ADDITIONAL_CONFIG_DIRS; do
  __initialize_system_etc "$config_2_etc" 2>/dev/stderr | tee -p -a "/data/logs/init.txt"
done
__initialize_replace_variables "$ETC_DIR" "$CONF_DIR" "$ADDITIONAL_CONFIG_DIRS" "$WWW_ROOT_DIR"
__initialize_database
__update_conf_files
__pre_execute
__fix_permissions "$SERVICE_USER" "$SERVICE_GROUP"
__run_pre_execute_checks 2>/dev/stderr | tee -a -p "/data/logs/entrypoint.log" "/data/logs/init.txt" || return 20
__run_start_script 2>>/dev/stderr | tee -p -a "/data/logs/entrypoint.log"
errorCode=$?
if [ -n "$EXEC_CMD_BIN" ]; then
  if [ "$errorCode" -eq 0 ]; then
    SERVICE_EXIT_CODE=0
    SERVICE_IS_RUNNING="yes"
  else
    SERVICE_EXIT_CODE=$errorCode
    SERVICE_IS_RUNNING="${SERVICE_IS_RUNNING:-no}"
    if [ ! -s "$SERVICE_PID_FILE" ]; then
      rm -Rf "$SERVICE_PID_FILE"
    fi
  fi
  SERVICE_EXIT_CODE=0
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
__post_execute 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt" &
# - - - - - - - - - - - - - - - - - - - - - - - - -
__banner "Initializing of $SERVICE_NAME has completed with statusCode: $SERVICE_EXIT_CODE" | tee -p -a "/data/logs/entrypoint.log" "/data/logs/init.txt"
__script_exit $SERVICE_EXIT_CODE
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
