{
  fetchFromGitHub,
  lib,
  unstableGitUpdater,
  buildDotnetModule,
  dotnetCorePackages,
  ffmpeg,
}:
buildDotnetModule rec {
  pname = "watt-toolkit";
  version = "3.2.0-unstable-2026-11-17";

  src = fetchFromGitHub {
    owner = "BeyondDimension";
    repo = "SteamTools";
    rev = "873fd4522758b5cce23ffc695061c56c0d8bef5e";
    hash = "sha256-36urbmCrDnHXs1Lt6j4cJlXHWyst5sX5lFLDObWlj6k=";
    fetchSubmodules = true;
  };

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/BeyondDimension/SteamTools";
  };
  projectFile = "WattToolkit.sln";
  nugetDeps = ./deps.json; # see "Generating and updating NuGet dependencies" section for details

  dotnet-sdk = dotnetCorePackages.sdk_9_0;
  dotnet-runtime = dotnetCorePackages.runtime_9_0;

  executables = [ ]; # This wraps "$out/lib/$pname/foo" to `$out/bin/foo`.

  packNupkg = true; # This packs the project as "foo-0.1.nupkg" at `$out/share`.

  runtimeDeps = [ ffmpeg ]; # This will wrap ffmpeg's library path into `LD_LIBRARY_PATH`.
  meta = {
    maintainers = import ../maintainers.nix;
    homepage = "https://steampp.net";
    description = "an open source cross-platform multi-purpose game toolkit";
    license = lib.licenses.gpl3Only;
    broken = true;
  };
}
