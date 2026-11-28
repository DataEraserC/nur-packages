#!/bin/sh
# Two faces of one agent:
#   --acp        stdio ACP bridge (WebMux chat, and Martty's agent child)
#   --resume ID  Martty terminal UI attached to an existing ACP session
#   no args      fresh Martty terminal UI
set -eu

: "${ZCODE_ACP_NATIVE:?}"
: "${ZCODE_ACP_MARTTY:?}"

session_root="${HOME:?}/.zcode/martty/sessions"

case "${1:-}" in
--acp)
	shift
	exec "$ZCODE_ACP_NATIVE" "$@"
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
		--session-id "$session_id" \
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
