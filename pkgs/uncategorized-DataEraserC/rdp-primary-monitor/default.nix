{
  lib,
  stdenv,
  fetchFromGitHub,
  glib,
  jq,
}:

let
  uuid = "rdp-primary-monitor@michal-b-bozek.github.io";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rdp-primary-monitor";
  version = "0.1.0-unstable-2026-10-26";

  # Upstream HEAD b537918949ee7ce6117845ade412ba2c9569a5b1, dated 2026-10-26.
  src = fetchFromGitHub {
    owner = "michal-b-bozek";
    repo = "rdp-primary-monitor";
    rev = "b537918949ee7ce6117845ade412ba2c9569a5b1";
    hash = "sha256-O7iQ1zIYV8L8UDLvec0QDNxpW5hkZvsvIhKXoJHo8WU=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    glib
    jq
  ];

  buildPhase = ''
    runHook preBuild
    glib-compile-schemas --strict src/schemas
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/gnome-shell/extensions/${uuid}
    cp -r src/. $out/share/gnome-shell/extensions/${uuid}
    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    extension="$out/share/gnome-shell/extensions/${uuid}"
    test -f "$extension/metadata.json"
    test -f "$extension/extension.js"
    test -f "$extension/schemas/gschemas.compiled"
    test "$(jq -r .uuid "$extension/metadata.json")" = "${uuid}"
    runHook postInstallCheck
  '';

  passthru.extensionUuid = uuid;

  meta = {
    description = "GNOME Shell extension making an RDP client's virtual monitor primary while connected";
    homepage = "https://github.com/michal-b-bozek/rdp-primary-monitor";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
})
