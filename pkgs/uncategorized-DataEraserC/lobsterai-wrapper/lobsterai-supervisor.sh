#!/usr/bin/env bash
# Supervised launcher for LobsterAI.
#
# LobsterAI spawns its OpenClaw engine (an `openclaw-gateway` child process) and
# never outlives it. Start it from a terminal or over waypipe and the engine is
# reparented to init when Electron dies, keeps the state directory lock, and the
# next launch is refused with "another gateway already owns this state
# directory"; the in-app Quick Repair cannot help because it needs the same
# exclusive lock.
#
# This launcher gives the app an owner:
#   1. before starting, reap engines left behind by a session that is gone,
#   2. run the app in its own session, so Ctrl-C and SIGHUP reach only us,
#   3. on exit, TERM (then KILL) the whole process group, engine included.
#
# Escape hatches:
#   LOBSTERAI_SUPERVISE=0 lobsterai   start without the watchdog
#   lobsterai --no-supervise          same
#   lobsterai --stop-engine           stop live engines of this user and exit
set +e # the wrapper may pass -e; this script decides its own error handling
set -uo pipefail

real=${LOBSTERAI_REAL_BIN:?LOBSTERAI_REAL_BIN is not set}
uid=$(id -u)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
lock_dir="$config_home/LobsterAI/openclaw/state/tmp/openclaw-$uid"

log() { printf 'lobsterai: %s\n' "$*" >&2; }

# pids recorded in the gateway lock files of this state directory
lock_pids() {
	local f
	for f in "$lock_dir"/gateway.state.lock "$lock_dir"/gateway.*.lock; do
		[[ -f $f ]] || continue
		sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$f"
	done | sort -u
}

# the engine rewrites its process title; the app keeps its binary path
is_engine() {
	local pid=$1 args comm
	[[ -d /proc/$pid ]] || return 1
	comm=$(cat "/proc/$pid/comm" 2>/dev/null)
	[[ $comm == openclaw-gateway* ]] && return 0
	args=$(ps -p "$pid" -o args= 2>/dev/null) || return 1
	[[ $args == openclaw-gateway || $args == 'openclaw-gateway '* ]]
}

# pid of a live LobsterAI app that owns this engine, empty when orphaned
engine_parent() {
	local pid=$1 ppid args
	ppid=$(ps -p "$pid" -o ppid= 2>/dev/null)
	ppid=${ppid//[[:space:]]/}
	[[ -n $ppid && $ppid != 0 && $ppid != 1 ]] || return 0
	args=$(ps -p "$ppid" -o args= 2>/dev/null) || return 0
	# A gateway reparented to systemd has no app in its parent slot, so anything
	# that is not the app itself means the session that started it is gone.
	[[ $args == *LobsterAI* ]] && printf '%s\n' "$ppid"
}

stop_pid() {
	local pid=$1 i
	kill -TERM "$pid" 2>/dev/null || return 0
	for i in $(seq 1 25); do
		[[ -d /proc/$pid ]] || return 0
		sleep 0.2
	done
	kill -KILL "$pid" 2>/dev/null || true
}

reap_orphans() {
	local pid parent
	for pid in $(lock_pids); do
		is_engine "$pid" || continue
		parent=$(engine_parent "$pid" || true)
		if [[ -n $parent ]]; then
			log "engine $pid belongs to the running LobsterAI (pid $parent); leaving it alone"
			continue
		fi
		log "stopping engine $pid left behind by an earlier session"
		stop_pid "$pid"
	done
}

stop_engine() {
	local pid
	for pid in $(lock_pids); do
		is_engine "$pid" && stop_pid "$pid"
	done
	# engines that crashed before writing a lock, or lost it
	while read -r pid; do
		[[ -n $pid ]] && stop_pid "$pid"
	done < <(pgrep -u "$uid" -f '^openclaw-gateway$' || true)
}

cleanup() {
	trap - EXIT INT TERM HUP
	[[ -n ${child:-} ]] || return 0
	kill -TERM -- "-$child" 2>/dev/null || return 0
	for _ in $(seq 1 25); do
		kill -0 -- "-$child" 2>/dev/null || return 0
		sleep 0.2
	done
	kill -KILL -- "-$child" 2>/dev/null || true
}

case ${1:-} in
--stop-engine)
	stop_engine
	exit 0
	;;
--no-supervise)
	shift
	reap_orphans
	exec "$real" "$@"
	;;
esac

if [[ ${LOBSTERAI_SUPERVISE:-1} == 0 ]]; then
	reap_orphans
	exec "$real" "$@"
fi

reap_orphans

setsid "$real" "$@" </dev/null &
child=$!
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
wait "$child" || rc=$?
exit "${rc:-0}"
