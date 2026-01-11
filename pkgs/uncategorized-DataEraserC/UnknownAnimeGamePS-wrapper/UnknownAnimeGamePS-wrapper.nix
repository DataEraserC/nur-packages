{
  stdenvNoCC,
  lib,
  sources,
  fetchurl,
  jre_headless,
  procps,
  makeWrapper,
  UnknownAnimeGamePS,
  ...
}:
let
  resources = sources.AAA_UnknownAnimeGamePS-resources.src;
  keystore = fetchurl {
    url = "https://github.com/XeonSucksLAB/UnknownAnimeGamePS/raw/development/keystore.p12";
    hash = "sha256-apFbGtWacE3GjXU/6h2yseskAsob0Xc/NWEu2uC0v3M=";
  };
in
stdenvNoCC.mkDerivation rec {
  inherit (sources.AAA_UnknownAnimeGamePS) version;

  pname = sources.AAA_UnknownAnimeGamePS.pname + "-wrapper";

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
    procps
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt
    install -Dm644 ${UnknownAnimeGamePS}/share/UnknownAnimeGamePS/UnknownAnimeGamePS.jar $out/UnknownAnimeGamePS.jar

    ln -s ${resources}/Resources $out/opt/resources
    ln -s ${keystore} $out/opt/keystore.p12

    pushd $out/opt/
    # Without MongoDB, UnknownAnimeGamePS is expected to fail
    (${jre_headless}/bin/java -jar $out/UnknownAnimeGamePS.jar || true) | while read line; do
      [[ "''${line}" == *"Loading UnknownAnimeGamePS"* ]] && echo "Aborting loading" && pkill -9 java
      echo ''${line}
    done
    mv config.json config.example.json
    rm -rf logs
    popd

    makeWrapper ${jre_headless}/bin/java $out/bin/UnknownAnimeGamePS \
      --run "echo mkdir UnknownAnimeGamePS" \
      --run "mkdir UnknownAnimeGamePS" \
      --run "echo cp -r $out/opt/* UnknownAnimeGamePS/" \
      --run "cp -r $out/opt/* UnknownAnimeGamePS/" \
      --run "echo chmod -R +rw UnknownAnimeGamePS" \
      --run "chmod -R +rw UnknownAnimeGamePS" \
      --run "echo cd UnknownAnimeGamePS" \
      --run "cd UnknownAnimeGamePS" \
      --add-flags "-jar" \
      --add-flags "$out/UnknownAnimeGamePS.jar"

    runHook postInstall
  '';

  meta = {
    description = "A server software reimplementation for a certain anime game.";
    homepage = "https://github.com/XeonSucksLAB/UnknownAnimeGamePS";
    mainProgram = "UnknownAnimeGamePS";
    license = [ lib.licenses.agpl3Only ];
  };
}
