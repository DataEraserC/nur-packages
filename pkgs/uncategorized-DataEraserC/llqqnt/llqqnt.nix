#https://github.com/Prismwork/llqqnt-nix/blob/trunk/pkgs/llqqnt.nix
{
  appimageTools,
  buildFHSUserEnv,
  pkg-config,
  qq,
  ...
}:
let
  LiteLoaderQQNT_REV = "af1d19abd92d11f2d0316a940592593f3b254705";
  LiteLoaderQQNT_URL = "https://github.com/LiteLoaderQQNT/LiteLoaderQQNT";
  LiteLoaderQQNT_SRC = fetchGit {
    url = LiteLoaderQQNT_URL;
    rev = LiteLoaderQQNT_REV;
    allRefs = true;
    submodules = true;
  };
  fhs =
    # create a fhs environment by command `fhs`, so we can run non-nixos packages in nixos!
    let
      base = appimageTools.defaultFhsEnvArgs;
    in
    buildFHSUserEnv (
      base
      // {
        name = "fhs";
        targetPkgs = pkgs: (base.targetPkgs pkgs) ++ [ pkg-config ];
        profile = "export FHS=1";
        runScript = "bash";
        extraOutputsToInstall = [ "dev" ];
      }
    );
in
(qq.override {
  # can not work and i have no idea
  # inherit commandLineArgs;
}).overrideAttrs
  (
    {
      # nativeBuildInputs ? [ ],
      runtimeDependencies ? [ ],
      # buildInputs ? [ ],
      installPhase,
      ...
    }:
    {
      runtimeDependencies = runtimeDependencies ++ [ fhs ];
      installPhase =
        builtins.replaceStrings
          [
            ''
              makeShellWrapper $out/opt/QQ/qq $out/bin/qq \
            ''
            "--enable-features=WaylandWindowDecorations"
          ]
          [
            ''
              makeShellWrapper $out/opt/QQ/qq $out/bin/llqqnt \
                --prefix LITELOADERQQNT_PROFILE_TEST : ''${XDG_DATA_HOME:-~/.local/share}/LLQQNT \
                --prefix LITELOADERQQNT_PROFILE_TEST2 : ~/.local/share/LLQQNT \
            ''
            "--enable-features=WaylandWindowDecorations --enable-wayland-ime"
          ]
          installPhase;
      postInstall = ''
        # Patch QQ
        sed -i "1s@^@require(String.raw\`${LiteLoaderQQNT_SRC}\`);\n@" $out/opt/QQ/resources/app/app_launcher/index.js
        mkdir -vp $out/opt/QQ/resources/app/application/
        cp -f ${LiteLoaderQQNT_SRC}/src/preload.js $out/opt/QQ/resources/app/application/
        # Use FHS environment run Patched QQ
        sed -i "s@^Exec=.*@Exec=${fhs}/bin/fhs -c 'LITELOADERQQNT_PROFILE=~/.local/share/LLQQNT $out/bin/llqqnt %U'@g" $out/share/applications/qq.desktop
      '';
    }
  )
