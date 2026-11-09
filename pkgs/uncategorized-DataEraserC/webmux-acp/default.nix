{
  webmux,
}:

# Test build only. The main `webmux` package keeps its own updateScript and
# follows upstream releases; this overlay adds the local, un-PR'd
# `feat/external-acp-agents` change on top of whatever version it currently
# pins, so the generic ACP / wrapper support can be tried without touching the
# updateable package or publishing anything upstream.
webmux.overrideAttrs (old: {
  pname = "webmux-acp";

  patches = (old.patches or [ ]) ++ [
    ./patches/external-acp-agents.patch
  ];

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit webmux;
  };

  meta = (old.meta or { }) // {
    description = "WebMux test build with config-driven ACP agents and wrapper commands";
  };
})
