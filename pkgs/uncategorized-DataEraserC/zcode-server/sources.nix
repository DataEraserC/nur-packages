# Source Server releases: same CDN directory as the desktop app, per version.
{
  version = "4.0.0";
  assets = {
    x86_64-linux = {
      name = "zcode-server-linux-x64.tar.gz";
      sha256 = "sha256-5o8de5RTa5Uwg0i5+YEC15IFnjyf5FpZJmDwev1esxo=";
      size = 97544737;
    };
    aarch64-linux = {
      name = "zcode-server-linux-arm64.tar.gz";
      sha256 = "sha256-ObH5dWCglWR+/zmknjR12bPKYRr2YdIwM7fttL3+tgA=";
      size = 96716929;
    };
  };
}
