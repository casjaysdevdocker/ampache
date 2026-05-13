#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# casjaysdevdocker/ampache - mariadb init.d (runs before 99-ampache.sh)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1003,SC2016,SC2031,SC2120,SC2155,SC2199,SC2317
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
trap 'retVal=$?;[ "$SERVICE_IS_RUNNING" != "yes" ] && [ -f "$SERVICE_PID_FILE" ] && rm -Rf "$SERVICE_PID_FILE";exit $retVal' SIGINT SIGTERM EXIT
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "/config/.debug" ] && [ -z "$DEBUGGER_OPTIONS" ] && export DEBUGGER_OPTIONS="$(<"/config/.debug")" || DEBUGGER_OPTIONS="${DEBUGGER_OPTIONS:-}"
{ [ "$DEBUGGER" = "on" ] || [ -f "/config/.debug" ]; } && echo "Enabling debugging" && set -xo pipefail -x$DEBUGGER_OPTIONS && export DEBUGGER="on" || set -o pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export PATH="/usr/local/etc/docker/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"
SCRIPT_FILE="$0"
SERVICE_NAME="mariadb"
__script_exit() {
	local exit_code="${1:-0}"
	if [ "${BASH_SOURCE[0]}" != "${0}" ]; then return "$exit_code"; else exit "$exit_code"; fi
}
SCRIPT_NAME="$(basename -- "$SCRIPT_FILE" 2>/dev/null)"
if [ ! -f "/run/.start_init_scripts.pid" ]; then
	echo "__start_init_scripts function hasn't been Initialized" >&2
	SERVICE_IS_RUNNING="no"
	__script_exit 1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "/usr/local/etc/docker/functions/entrypoint.sh" ]; then
	. "/usr/local/etc/docker/functions/entrypoint.sh"
fi
for set_env in "/root/env.sh" "/usr/local/etc/docker/env"/*.sh "/config/env"/*.sh; do
	[ -f "$set_env" ] && . "$set_env"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
START_SCRIPT="/usr/local/etc/docker/exec/$SERVICE_NAME"
RESET_ENV="no"
WWW_ROOT_DIR="/usr/local/share/ampache/public"
DATA_DIR="/data/db/mariadb"
CONF_DIR="/config/my.cnf.d"
ETC_DIR="/etc/my.cnf.d"
VAR_DIR=""
TMP_DIR="/tmp/mysql"
RUN_DIR="/run/mysqld"
LOG_DIR="/data/logs/mariadb"
WORK_DIR=""
SERVICE_PORT="3306"
RUNAS_USER="root"
SERVICE_USER="mysql"
SERVICE_GROUP="mysql"
RANDOM_PASS_USER=""
RANDOM_PASS_ROOT=""
SERVICE_UID="0"
SERVICE_GID="0"
EXEC_CMD_BIN='mariadbd'
EXEC_CMD_ARGS='--user=$SERVICE_USER --datadir=$DATABASE_DIR --socket=/run/mysqld/mysqld.sock'
EXEC_PRE_SCRIPT=''
IS_WEB_SERVER="no"
IS_DATABASE_SERVICE="yes"
USES_DATABASE_SERVICE="no"
DATABASE_SERVICE_TYPE="mariadb"
PRE_EXEC_MESSAGE=""
POST_EXECUTE_WAIT_TIME="1"
PATH="$PATH:."
IP4_ADDRESS="$(__get_ip4)"
IP6_ADDRESS="$(__get_ip6)"
ROOT_FILE_PREFIX="/config/secure/auth/root"
USER_FILE_PREFIX="/config/secure/auth/user"
root_user_name="${MARIADB_ROOT_USER_NAME:-root}"
root_user_pass="${MARIADB_ROOT_PASS_WORD:-random}"
user_name="${MARIADB_USER_NAME:-ampache}"
user_pass="${MARIADB_USER_PASS_WORD:-random}"
DATABASE_CREATE="${DATABASE_CREATE:-ampache}"
[ -f "/config/env/mariadb.script.sh" ] && . "/config/env/mariadb.script.sh"
[ -f "/config/env/mariadb.sh" ] && . "/config/env/mariadb.sh"
ADD_APPLICATION_FILES=""
ADD_APPLICATION_DIRS=""
APPLICATION_FILES="$LOG_DIR/$SERVICE_NAME.log"
APPLICATION_DIRS="$ETC_DIR $CONF_DIR $LOG_DIR $TMP_DIR $RUN_DIR $VAR_DIR"
ADDITIONAL_CONFIG_DIRS=""
CMD_ENV=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_precopy() {
	local hostname=${HOSTNAME}
	if builtin type -t __run_precopy_local | grep -q 'function'; then __run_precopy_local; fi
}
__execute_prerun() {
	local hostname=${HOSTNAME}
	mkdir -p /run/mysqld /data/db/mariadb /data/logs/mariadb
	chown -Rf mysql:mysql /run/mysqld /data/db/mariadb /data/logs/mariadb 2>/dev/null || true
	if builtin type -t __execute_prerun_local | grep -q 'function'; then __execute_prerun_local; fi
}
__run_pre_execute_checks() {
	local exitStatus=0
	local pre_execute_checks_MessageST="Running preexecute check for $SERVICE_NAME"
	local pre_execute_checks_MessageEnd="Finished preexecute check for $SERVICE_NAME"
	__banner "$pre_execute_checks_MessageST"
	{
		if [ ! -d "$DATABASE_DIR" ] || [ ! -f "$DATABASE_DIR/ibdata1" ] && [ ! -d "$DATABASE_DIR/mysql" ]; then
			rm -Rf "${DATABASE_DIR:?}"/*
			mkdir -p "$DATABASE_DIR"
			chown -Rf $SERVICE_USER:$SERVICE_GROUP "$DATABASE_DIR"
			mariadb-install-db --datadir=$DATABASE_DIR --user=$SERVICE_USER --auth-root-authentication-method=normal 2>/dev/null || \
			  mysql_install_db --datadir=$DATABASE_DIR --user=$SERVICE_USER 2>/dev/null
		fi
	}
	exitStatus=$?
	__banner "$pre_execute_checks_MessageEnd: Status $exitStatus"
	if [ $exitStatus -ne 0 ]; then
		echo "The pre-execution check has failed" >&2
		[ -f "$SERVICE_PID_FILE" ] && rm -Rf "$SERVICE_PID_FILE"
		__script_exit 1
	fi
	if builtin type -t __run_pre_execute_checks_local | grep -q 'function'; then __run_pre_execute_checks_local; fi
	return $exitStatus
}
__update_conf_files() {
	local exitCode=0
	local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
	if builtin type -t __update_conf_files_local | grep -q 'function'; then __update_conf_files_local; fi
	return $exitCode
}
__pre_execute() {
	local exitCode=0
	sleep 5
	if builtin type -t __pre_execute_local | grep -q 'function'; then __pre_execute_local; fi
	return $exitCode
}
__post_execute() {
	local pid=""
	local retVal=0
	local ctime=${POST_EXECUTE_WAIT_TIME:-1}
	local waitTime=$((ctime * 60))
	local postMessageST="Running post commands for $SERVICE_NAME"
	local postMessageEnd="Finished post commands for $SERVICE_NAME"
	local DATABASE_ROOT_PASSWORD="${root_user_pass:-$(__random_password)}"
	local db_root_user="${MYSQL_ROOT_USER_NAME:-root}"
	echo "$DATABASE_ROOT_PASSWORD" >"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass" 2>/dev/null || true
	sleep $waitTime
	(
		__banner "$postMessageST"
		# Wait for socket
		local i=0
		while [ ! -S /run/mysqld/mysqld.sock ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
		if [ -f "$CONF_DIR/init.sh" ]; then bash -c "$CONF_DIR/init.sh"; fi
		if [ -n "$DATABASE_CREATE" ]; then
			mariadb -v -u $db_root_user <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`$DATABASE_CREATE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
MYSQL_SCRIPT
		fi
		if [ "$user_name" != "root" ] && [ -n "$user_name" ]; then
			mariadb -v -u $db_root_user <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '$user_name'@'%' IDENTIFIED BY '$user_pass';
CREATE USER IF NOT EXISTS '$user_name'@'localhost' IDENTIFIED BY '$user_pass';
MYSQL_SCRIPT
		fi
		if [ "$user_name" != "root" ] && [ -n "$DATABASE_CREATE" ]; then
			mariadb -v -u $db_root_user <<MYSQL_SCRIPT
GRANT ALL PRIVILEGES ON \`$DATABASE_CREATE\`.* TO '$user_name'@'%';
GRANT ALL PRIVILEGES ON \`$DATABASE_CREATE\`.* TO '$user_name'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
		fi
		mariadb -v -u $db_root_user <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$DATABASE_ROOT_PASSWORD';
ALTER USER 'root'@'%' IDENTIFIED BY '$DATABASE_ROOT_PASSWORD';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DATABASE_ROOT_PASSWORD';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
		__banner "$postMessageEnd: Status $retVal"
	) 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt" &
	pid=$!
	if builtin type -t __post_execute_local | grep -q 'function'; then __post_execute_local; fi
	return $retVal
}
__pre_message() {
	local exitCode=0
	[ -n "$PRE_EXEC_MESSAGE" ] && eval echo "$PRE_EXEC_MESSAGE"
	if builtin type -t __pre_message_local | grep -q 'function'; then __pre_message_local; fi
	return $exitCode
}
__update_ssl_conf() {
	local exitCode=0
	if builtin type -t __update_ssl_conf_local | grep -q 'function'; then __update_ssl_conf_local; fi
	return $exitCode
}
__create_service_env() {
	local exitCode=0
	if [ ! -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ]; then
		cat <<EOF | tee -p "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Generated by 09-mariadb.sh - edit to override defaults
#root_user_name="root"
#root_user_pass="random"
#user_name="ampache"
#user_pass="random"
#DATABASE_CREATE="ampache"
EOF
	fi
	if [ ! -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" ]; then
		__run_precopy_local() { true; }
		__execute_prerun_local() { true; }
		__run_pre_execute_checks_local() { true; }
		__update_conf_files_local() { true; }
		__pre_execute_local() { true; }
		__post_execute_local() { true; }
		__pre_message_local() { true; }
		__update_ssl_conf_local() { true; }
	fi
	__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" || exitCode=$((exitCode + 1))
	__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" || exitCode=$((exitCode + 1))
	return $exitCode
}
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
	[ -f "$CONF_DIR/$SERVICE_NAME.exec_cmd.sh" ] && . "$CONF_DIR/$SERVICE_NAME.exec_cmd.sh"
	if [ -z "$cmd" ]; then
		__post_execute 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt"
		retVal=$?
		echo "Initializing $SCRIPT_NAME has completed"
		__script_exit $retVal
	else
		if [ ! -x "$cmd" ]; then echo "$name is not a valid executable"; return 2; fi
		if __proc_check "$name" || __proc_check "$cmd"; then echo "$name is already running" >&2; return 0; fi
		[ -n "$SERVICE_USER" ] && echo "Setting up $cmd to run as $SERVICE_USER" || SERVICE_USER="root"
		[ -n "$SERVICE_PORT" ] && echo "$name will be running on port $SERVICE_PORT" || SERVICE_PORT=""
		export cmd_exec="$cmd $args"
		message="Starting service: $name $args"
		[ -n "$su_exec" ] && echo "using $su_exec" | tee -a -p "/data/logs/init.txt"
		echo "$message" | tee -a -p "/data/logs/init.txt"
		su_cmd touch "$SERVICE_PID_FILE"
		execute_command="$(__trim "$su_exec $cmd_exec")"
		if [ ! -f "$START_SCRIPT" ]; then
			cat <<EOF >"$START_SCRIPT"
#!/usr/bin/env bash
trap 'exitCode=\$?;if [ \$exitCode -ne 0 ] && [ -f "\$SERVICE_PID_FILE" ]; then rm -Rf "\$SERVICE_PID_FILE"; fi; exit \$exitCode' EXIT
set -Eeo pipefail
retVal=10
cmd="$cmd"
SERVICE_NAME="$SERVICE_NAME"
SERVICE_PID_FILE="$SERVICE_PID_FILE"
$execute_command 2>>"/dev/stderr" >>"$LOG_DIR/$SERVICE_NAME.log" &
execPid=\$!
sleep 2
checkPID="\$(ps ax | awk '{print \$1}' | grep -v grep | grep "\$execPid$" || false)"
[ -n "\$execPid"  ] && [ -n "\$checkPID" ] && echo "\$execPid" >"\$SERVICE_PID_FILE" && retVal=0 || retVal=10
[ "\$retVal" = 0 ] && echo "\$cmd has been started" || echo "Failed to start $execute_command" >&2
exit \$retVal
EOF
		fi
		[ -x "$START_SCRIPT" ] || chmod 755 -Rf "$START_SCRIPT"
		[ "$CONTAINER_INIT" = "yes" ] || eval sh -c "$START_SCRIPT"
		runExitCode=$?
	fi
	return $runExitCode
}
__run_secure_function() {
	local filesperms
	for filesperms in "${USER_FILE_PREFIX}"/* "${ROOT_FILE_PREFIX}"/*; do
		[ -e "$filesperms" ] && { chmod -Rf 600 "$filesperms"; chown -Rf $SERVICE_USER:$SERVICE_USER "$filesperms" 2>/dev/null; }
	done 2>/dev/null
	unset filesperms
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" && . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" && . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh"
SERVICE_EXIT_CODE=0
EXEC_CMD_NAME="$(basename -- "$EXEC_CMD_BIN")"
SERVICE_PID_FILE="/run/init.d/$EXEC_CMD_NAME.pid"
SERVICE_PID_NUMBER="$(__pgrep)"
EXEC_CMD_BIN="$(type -P "$EXEC_CMD_BIN" || echo "$EXEC_CMD_BIN")"
EXEC_PRE_SCRIPT="$(type -P "$EXEC_PRE_SCRIPT" || echo "$EXEC_PRE_SCRIPT")"
__check_service "$1" && SERVICE_IS_RUNNING=yes
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"
[ -d "$RUN_DIR" ] || mkdir -p "$RUN_DIR"
[ -n "$USER_FILE_PREFIX" ] && { [ -d "$USER_FILE_PREFIX" ] || mkdir -p "$USER_FILE_PREFIX"; }
[ -n "$ROOT_FILE_PREFIX" ] && { [ -d "$ROOT_FILE_PREFIX" ] || mkdir -p "$ROOT_FILE_PREFIX"; }
[ -n "$RUNAS_USER" ] || RUNAS_USER="root"
[ -n "$SERVICE_USER" ] || SERVICE_USER="$RUNAS_USER"
[ -n "$SERVICE_GROUP" ] || SERVICE_GROUP="${SERVICE_USER:-$RUNAS_USER}"
if [ "$IS_DATABASE_SERVICE" = "yes" ]; then
	DATABASE_USER_NORMAL="${ENV_DATABASE_USER:-${DATABASE_USER_NORMAL:-$user_name}}"
	DATABASE_PASS_NORMAL="${ENV_DATABASE_PASSWORD:-${DATABASE_PASS_NORMAL:-$user_pass}}"
	DATABASE_USER_ROOT="${ENV_DATABASE_ROOT_USER:-${DATABASE_USER_ROOT:-$root_user_name}}"
	DATABASE_PASS_ROOT="${ENV_DATABASE_ROOT_PASSWORD:-${DATABASE_PASS_ROOT:-$root_user_pass}}"
	[ -n "$DATABASE_PASS_NORMAL" ] && [ ! -f "${USER_FILE_PREFIX}/db_pass_user" ] && echo "$DATABASE_PASS_NORMAL" >"${USER_FILE_PREFIX}/db_pass_user"
	[ -n "$DATABASE_PASS_ROOT" ] && [ ! -f "${ROOT_FILE_PREFIX}/db_pass_root" ] && echo "$DATABASE_PASS_ROOT" >"${ROOT_FILE_PREFIX}/db_pass_root"
fi
DATABASE_DIR="${DATABASE_DIR_MARIADB:-/data/db/mariadb}"
DATABASE_BASE_DIR="$DATABASE_DIR"
[ -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ] && . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
[ "$user_pass" = "random" ] && user_pass="$(__random_password ${RANDOM_PASS_USER:-16})"
[ "$root_user_pass" = "random" ] && root_user_pass="$(__random_password ${RANDOM_PASS_ROOT:-16})"
[ -n "$user_name" ] && echo "$user_name" >"${USER_FILE_PREFIX}/${SERVICE_NAME}_name"
[ -n "$user_pass" ] && echo "$user_pass" >"${USER_FILE_PREFIX}/${SERVICE_NAME}_pass"
[ -n "$root_user_name" ] && echo "$root_user_name" >"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_name"
[ -n "$root_user_pass" ] && echo "$root_user_pass" >"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass"
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"
[ -d "$RUN_DIR" ] || mkdir -p "$RUN_DIR"
__file_exists_with_content "${USER_FILE_PREFIX}/${SERVICE_NAME}_name" && user_name="$(<"${USER_FILE_PREFIX}/${SERVICE_NAME}_name")"
__file_exists_with_content "${USER_FILE_PREFIX}/${SERVICE_NAME}_pass" && user_pass="$(<"${USER_FILE_PREFIX}/${SERVICE_NAME}_pass")"
__file_exists_with_content "${ROOT_FILE_PREFIX}/${SERVICE_NAME}_name" && root_user_name="$(<"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_name")"
__file_exists_with_content "${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass" && root_user_pass="$(<"${ROOT_FILE_PREFIX}/${SERVICE_NAME}_pass")"
__file_exists_with_content "${USER_FILE_PREFIX}/db_pass_user" && DATABASE_PASS_NORMAL="$(<"${USER_FILE_PREFIX}/db_pass_user")"
__file_exists_with_content "${ROOT_FILE_PREFIX}/db_pass_root" && DATABASE_PASS_ROOT="$(<"${ROOT_FILE_PREFIX}/db_pass_root")"
sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
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
	if [ "$errorCode" -eq 0 ]; then SERVICE_EXIT_CODE=0; SERVICE_IS_RUNNING="yes"; else SERVICE_EXIT_CODE=$errorCode; SERVICE_IS_RUNNING="${SERVICE_IS_RUNNING:-no}"; [ -s "$SERVICE_PID_FILE" ] || rm -Rf "$SERVICE_PID_FILE"; fi
	SERVICE_EXIT_CODE=0
fi
__post_execute 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt" &
__banner "Initializing of $SERVICE_NAME has completed with statusCode: $SERVICE_EXIT_CODE" | tee -p -a "/data/logs/entrypoint.log" "/data/logs/init.txt"
__script_exit $SERVICE_EXIT_CODE
