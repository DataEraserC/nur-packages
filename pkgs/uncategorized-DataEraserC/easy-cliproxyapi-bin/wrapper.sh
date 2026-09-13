#!/bin/sh
set -eu

src="@out@/libexec/easy-cliproxyapi"
core="@core@"
runtime="${XDG_DATA_HOME:-${HOME:?HOME is not set}/.local/share}/easy-cliproxyapi"

mkdir -p "$runtime/cpa-core"
@coreutils@/bin/install -C -m755 "$src/EasyCLIProxyAPI" "$runtime/EasyCLIProxyAPI"
@coreutils@/bin/install -C -m644 "$src/config.example.yaml" "$runtime/cpa-core/config.example.yaml"
ln -sfn "$core/bin/server" "$runtime/cpa-core/cli-proxy-api"
printf '{\n  "version": "%s",\n  "assetName": "nix-cliproxyapi-%s",\n  "installedAtUnix": 0\n}\n' \
  "@coreversion@" "@coreversion@" >"$runtime/cpa-core/cpa-gui-meta.json"
printf '%s\n' "@coreversion@" >"$runtime/core-version.txt"

exec "$runtime/EasyCLIProxyAPI" "$@"
