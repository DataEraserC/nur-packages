#https://github.com/Prismwork/llqqnt-nix/blob/trunk/pkgs/llqqnt.nix
{
  appimageTools,
  buildFHSEnv,
  pkg-config,
  qq,
  sources,
  ...
}:
let
  LiteLoaderQQNT_SRC = sources.AAA_LiteLoaderQQNT.src;
  fhs =
    # create a fhs environment by command `fhs`, so we can run non-nixos packages in nixos!
    let
      base = appimageTools.defaultFhsEnvArgs;
    in
    buildFHSEnv (
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
      version,
      ...
    }:
    {
      __intentionallyOverridingVersion = true;
      version = "qq=${version}+llqqnt_rev=${sources.LiteLoaderQQNT.version}";
      runtimeDependencies = runtimeDependencies ++ [ fhs ];
      installPhase =
        installPhase
        + ''
          mv $out/bin/qq $out/bin/origin_qq
          mv $out/share/applications/qq.desktop $out/share/applications/llqqnt.desktop
          makeShellWrapper $out/bin/origin_qq  $out/bin/llqqnt \
            --prefix LITELOADERQQNT_PROFILE : "''${LITELOADERQQNT_PROFILE:-''${XDG_DATA_HOME:-''${HOME:-~}/.local/share}/LLQQNT}"

          # Patch QQ
          echo "require(String.raw\`${LiteLoaderQQNT_SRC}\`)" > $out/opt/resources/app/app_launcher/llqqnt.js

          sed -i 's#"main": ".*"#"main": "./app_launcher/llqqnt.js"#' $out/opt/resources/app/package.json

          # Use FHS environment run Patched QQ
          # sed -i "s@^Exec=.*@Exec=${fhs}/bin/fhs -c 'LITELOADERQQNT_PROFILE=~/.local/share/LLQQNT $out/bin/llqqnt %U'@g" $out/share/applications/llqqnt.desktop
          sed -i "s@^Exec=.*@Exec=${fhs}/bin/fhs -c '$out/bin/llqqnt %U'@g" $out/share/applications/llqqnt.desktop
          sed -i "s@^Name=.*@Name=LLQQNT@g" $out/share/applications/llqqnt.desktop
        '';
      meta.broken = true;
    }
  )
