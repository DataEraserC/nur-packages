{
  webmux,
}:

webmux.overrideAttrs (old: {
  pname = "webmux-acp";

  patches = (old.patches or [ ]) ++ [
    ./patches/codebuddy-agent.patch
  ];

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit webmux;
  };

  meta = (old.meta or { }) // {
    description = "Browser-based persistent terminal server with extra ACP agent adapters";
  };
})
