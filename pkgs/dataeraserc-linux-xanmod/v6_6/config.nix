{ lib, ... }:
with lib.kernel;
{
  LOCALVERSION = freeform "-dataeraserc";
  WERROR = no;
  # codec2
  # https://github.com/remote-android/redroid-doc/issues/407#issuecomment-1661372675
  DMABUF_HEAPS = yes;
  DMABUF_HEAPS_SYSTEM = yes;
}
