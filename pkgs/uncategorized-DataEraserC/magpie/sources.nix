# Release assets of yetone/magpie-releases, one line per platform build.
# Rewrite with ./update.sh; it reads the release's SHA256SUMS.
{
  version = "0.1.4966";

  assets = {
    magpie-linux-amd64 = "c861c4e4b5323d206d520cb742502d403a3957ed97223d6c4a8503c823d3567e";
    magpie-linux-arm64 = "9d849d101b29abb7f6b4f90e01a515ad88c44f8a4a21137f54510f40646fdef7";
    magpie-cli-linux-amd64 = "6d2c09e183771d7c28a3187de3599fe530e363c3865e5156e57e00813c853069";
    magpie-cli-linux-arm64 = "f447dcea5f8cffa926aed59597fe333e52e07937fe34dea06151787d4f8f200b";
  };
}
