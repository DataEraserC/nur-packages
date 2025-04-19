{
  ciscoPacketTracer8,
  fetchurl,
  ...
}:
(ciscoPacketTracer8.override {
}).overrideAttrs
  (
    _oldAttrs:
    let
      new_src = fetchurl {
        url = "https://github.com/DataEraserC/nur-packages/releases/download/CiscoPacketTracer822_amd64_signed.deb/CiscoPacketTracer822_amd64_signed.deb";
        hash = "sha256-bNK4iR35LSyti2/cR0gPwIneCFxPP+leuA1UUKKn9y0=";
      };
    in
    {
      src = new_src;
    }
  )
