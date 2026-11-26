{
  meoo2api,
}:
meoo2api.overrideAttrs (old: {
  pname = "meoo2api-firefox";

  patches = (old.patches or [ ]) ++ [
    ./referrer-policy-same-origin.patch
  ];

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit meoo2api;
    aiProvenance = [
      {
        agent = "xiaohuanxiong";
        involvement = "authored";
      }
    ];
  };

  meta = old.meta // {
    description = "Meoo model gateway proxy patched so Firefox keeps a real Origin on console logins";
    mainProgram = "meoo2api";
  };
})
