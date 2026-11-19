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
  version = "3.2.0-unstable-2026-11-19";

  src = fetchFromGitHub {
    owner = "BeyondDimension";
    repo = "SteamTools";
    rev = "a2be9af772481c454e40e33e495bed21afe121e9";
    hash = "sha256-MWQ/RHRrg5Oen6MdfXokLnMhKv8ryqJCDmFWu7QPgZk=";
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
