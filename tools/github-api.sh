# shellcheck shell=bash
#
# Shared GitHub helpers for update scripts.
#
# api.github.com allows 60 unauthenticated requests per hour per IP, and the
# shared runners used by the auto-update workflow exhaust that constantly, so
# a plain `curl https://api.github.com/...` fails with 403. Every helper here:
#
#   1. authenticates with GITHUB_TOKEN/GH_TOKEN when the environment provides
#      one (5000 requests per hour), and retries once without it on 401 so a
#      stale/insufficient token degrades instead of breaking the update;
#   2. retries 403/429/5xx with bounded backoff, sleeping for the hourly reset
#      only when it is seconds away (a package update is capped at 600s);
#   3. falls back to GitHub's web endpoints (releases.atom, the
#      /releases/latest redirect, releases/expanded_assets) which serve the
#      same data without consuming the REST quota.
#
# Update scripts source this file relative to their own path, e.g.
#   source "$(dirname "$0")/../../../tools/github-api.sh"

_gh_token() {
  printf '%s' "${GITHUB_TOKEN:-${GH_TOKEN:-}}"
}

# gh_api <path-or-url>
# Prints the JSON body on success and returns non-zero when every attempt was
# rate limited or failed. Callers are expected to provide their own fallback.
gh_api() {
  local path="$1"
  local url
  case "$path" in
  http*) url="$path" ;;
  *) url="https://api.github.com/${path#/}" ;;
  esac

  local token hdrs payload code attempt wait reset now
  token="$(_gh_token)"
  hdrs="$(mktemp)"
  payload="$(mktemp)"

  for attempt in 1 2 3; do
    local -a curl_args=(
      -sS -o "$payload" -D "$hdrs" -w '%{http_code}'
      -H 'Accept: application/vnd.github+json'
      -H 'X-GitHub-Api-Version: 2022-11-28'
    )
    if [ -n "$token" ]; then
      curl_args+=(-H "Authorization: Bearer $token")
    fi

    code="$(curl "${curl_args[@]}" "$url" 2>/dev/null || echo 000)"

    case "$code" in
    2*)
      cat "$payload"
      rm -f "$hdrs" "$payload"
      return 0
      ;;
    401)
      # The token is unusable here (expired, wrong scope). Fall back to an
      # anonymous request instead of failing the whole package update.
      token=""
      ;;
    403 | 429)
      # Primary or secondary rate limit. X-RateLimit-Reset is a Unix
      # timestamp; waiting for a full hour would blow the package timeout, so
      # only sleep when the window is about to roll over.
      reset="$(sed -n 's/^[Xx]-[Rr]ate[Ll]imit-[Rr]eset: *//p' "$hdrs" | tr -d '\r' | head -n1)"
      now="$(date +%s)"
      wait=0
      if [ -n "$reset" ] && [ "$reset" -gt "$now" ] 2>/dev/null; then
        wait=$((reset - now + 1))
      fi
      if [ "$wait" -ge 1 ] && [ "$wait" -le 60 ]; then
        echo "github-api: rate limited, reset in ${wait}s" >&2
        sleep "$wait"
      else
        sleep $((attempt * 2))
      fi
      ;;
    *)
      sleep $((attempt * 2))
      ;;
    esac
  done

  echo "github-api: giving up on $url (last status $code)" >&2
  rm -f "$hdrs" "$payload"
  return 1
}

# gh_latest_tag <owner/repo>
# Newest release tag (no API quota when the REST call is unavailable).
gh_latest_tag() {
  local repo="$1" tag=""
  tag="$(gh_api "repos/$repo/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null || true)"
  if [ -z "$tag" ]; then
    # /releases/latest answers with a redirect to /releases/tag/<tag>.
    tag="$(curl -sS -o /dev/null -w '%{redirect_url}' "https://github.com/$repo/releases/latest" 2>/dev/null |
      sed -n 's|.*/releases/tag/||p')"
  fi
  if [ -z "$tag" ]; then
    # The release feed lists entries newest first.
    tag="$(curl -sSL "https://github.com/$repo/releases.atom" 2>/dev/null |
      grep -oE 'releases/tag/[^"<]+' | head -n1 | sed 's|releases/tag/||')"
  fi
  [ -n "$tag" ] || return 1
  printf '%s\n' "$tag"
}

# gh_release_tags <owner/repo> [<count>]
# Release tags, newest release first.
gh_release_tags() {
  local repo="$1" count="${2:-30}" tags=""
  tags="$(gh_api "repos/$repo/releases?per_page=$count" 2>/dev/null | jq -r '.[]?.tag_name' 2>/dev/null || true)"
  if [ -z "$tags" ]; then
    tags="$(curl -sSL "https://github.com/$repo/releases.atom" 2>/dev/null |
      grep -oE 'releases/tag/[^"<]+' | head -n "$count" | sed 's|releases/tag/||')"
  fi
  [ -n "$tags" ] || return 1
  printf '%s\n' "$tags"
}

# gh_release_assets <owner/repo> <tag>
# Asset file names of one release, one per line.
gh_release_assets() {
  local repo="$1" tag="$2" names=""
  names="$(gh_api "repos/$repo/releases/tags/$tag" 2>/dev/null | jq -r '.assets[]?.name' 2>/dev/null || true)"
  if [ -z "$names" ]; then
    # The web UI loads its asset list from expanded_assets; the download URLs
    # in that fragment carry the file names.
    names="$(curl -sSL "https://github.com/$repo/releases/expanded_assets/$tag" 2>/dev/null |
      grep -oE '/releases/download/[^"]+' | head -n 200 |
      sed 's|.*/releases/download/[^/]*/||' | sort -u)"
  fi
  [ -n "$names" ] || return 1
  printf '%s\n' "$names"
}
