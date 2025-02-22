{
  stdenv,
  callPackage,
  makeWrapper,
  qq,
  qq-original ? qq,
  bstar ? callPackage ./../bstar { },
}:
qq-original.overrideAttrs (oldAttrs: {
  nativeBuildInputs = oldAttrs.nativeBuildInputs or [ ] ++ [ makeWrapper ];

  buildInputs = oldAttrs.buildInputs or [ ];

  postInstall =
    (oldAttrs.postInstall or "")
    + ''
      for bin in $out/bin/*; do
        if [[ -x "$bin" && ! -L "$bin" ]]; then
          wrapProgram "$bin" \
            --prefix LD_PRELOAD : "${bstar}/lib/libbstar.so"
        fi
      done
    '';

  passthru = oldAttrs.passthru or { } // {
    debugEnv = stdenv.mkDerivation {
      name = "qq-debug-env";
      buildInputs = [ bstar ];
      shellHook = ''
        export LD_PRELOAD="${bstar}/lib/bstar-0.5.10.so"
      '';
    };
  };
})
