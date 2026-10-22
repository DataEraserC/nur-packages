{
  workbuddy,
  lib,
  jq,
}:
# Upstream ships no international Linux package: `www.workbuddy.ai/v2/update`
# still advertises 5.5.2 while that `.deb` is gone from download.codebuddy.ai,
# and both regions build the same Electron app. So this variant is the CN tree
# with the CLI product configuration repointed at the international deployment.
workbuddy.overrideAttrs (prevAttrs: {
  pname = "workbuddy-ai";

  postInstall = ''
    config=$out/opt/WorkBuddy/resources/app.asar.unpacked/cli/product.json
    chmod u+w "$config"
    ${lib.getExe jq} '
      .endpoint = "https://www.codebuddy.ai"
      | .isOversea = true
      | .dataFolderName = ".workbuddy-ai"
    ' "$config" >"$config.new"
    mv "$config.new" "$config"

    mv $out/bin/workbuddy $out/bin/workbuddy-ai

    # Both variants provide the same icon and desktop entry names, so rename
    # them to keep the two installable side by side.
    for icon in $out/share/icons/hicolor/*/apps/workbuddy.png; do
      mv "$icon" "''${icon%workbuddy.png}workbuddy-ai.png"
    done

    mv $out/share/applications/workbuddy.desktop \
      $out/share/applications/workbuddy-ai.desktop
    substituteInPlace $out/share/applications/workbuddy-ai.desktop \
      --replace-fail 'Name=WorkBuddy' 'Name=WorkBuddy International' \
      --replace-fail 'Icon=workbuddy' 'Icon=workbuddy-ai' \
      --replace-fail '/bin/workbuddy ' '/bin/workbuddy-ai '
  '';

  meta = prevAttrs.meta // {
    description = "AI agent desktop application for everyday office work, international deployment";
    homepage = "https://www.workbuddy.ai";
    mainProgram = "workbuddy-ai";
  };
})
