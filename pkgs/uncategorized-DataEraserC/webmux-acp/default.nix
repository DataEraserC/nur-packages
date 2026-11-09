{
  webmux,
}:

webmux.overrideAttrs (old: {
  pname = "webmux-acp";

  patches = (old.patches or [ ]) ++ [
    ./patches/generic-acp.patch
  ];

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit webmux;
  };

  meta = (old.meta or { }) // {
    description = "Browser-based persistent terminal server with config-driven ACP agents";
  };
})
