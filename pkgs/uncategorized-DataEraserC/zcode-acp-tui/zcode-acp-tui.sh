#!/bin/sh
# Two faces of one agent:
#   --acp        stdio ACP bridge (WebMux chat, and Martty's agent child)
#   --resume ID  Martty terminal UI attached to an existing ACP session
#   no args      fresh Martty terminal UI
set -eu

: "${ZCODE_ACP_NATIVE:?}"
: "${ZCODE_ACP_MARTTY:?}"

session_root="${HOME:?}/.zcode/martty/sessions"

run_native() {
	resume="${ZCODE_ACP_TUI_RESUME_SESSION:-}"
	if [ -z "$resume" ]; then
		"$ZCODE_ACP_NATIVE" "$@"
		return
	fi
	# Martty keeps its own durable session id. When WebMux asks us to resume,
	# it starts Martty without --session-id and we bind the ACP session by
	# rewriting its first session/new (or session/resume) to the WebMux id.
	while IFS= read -r line; do
		case "$line" in
		*'"session/new"'* | *'"session/resume"'*)
			line=$(printf '%s\n' "$line" | sed -E \
				-e 's/"method"[[:space:]]*:[[:space:]]*"session\/(new|resume)"/"method":"session\/resume"/')
			if printf '%s\n' "$line" | grep -q '"sessionId"'; then
				line=$(printf '%s\n' "$line" | sed -E \
					-e "s/\"sessionId\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"sessionId\":\"$resume\"/g")
			else
				line=$(printf '%s\n' "$line" | sed -E \
					-e "s/\"params\"[[:space:]]*:[[:space:]]*\{/\"params\":{\"sessionId\":\"$resume\",/")
			fi
			;;
		esac
		printf '%s\n' "$line"
	done | "$ZCODE_ACP_NATIVE" "$@"
}

case "${1:-}" in
--acp)
	shift
	run_native "$@"
	;;
--resume)
	if [ "$#" -lt 2 ]; then
		echo "usage: zcode-acp-tui --resume <session-id> [-- <tui args>]" >&2
		exit 2
	fi
	session_id=$2
	shift 2
	mkdir -p "$session_root"
	export ZCODE_ACP_TUI_RESUME_SESSION="$session_id"
	exec "$ZCODE_ACP_MARTTY" \
		--agent zcode-acp-tui \
		--agent-arg --acp \
		--session-root "$session_root" \
		"$@"
	;;
*)
	mkdir -p "$session_root"
	exec "$ZCODE_ACP_MARTTY" \
		--agent zcode-acp-tui \
		--agent-arg --acp \
		--session-root "$session_root" \
		"$@"
	;;
esac
