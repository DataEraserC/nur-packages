{
  lib,
  sources,
  python3Packages,
  ...
}:
with python3Packages;
buildPythonPackage rec {
  inherit (sources.xstatic-asciinema-player) pname version src;

  meta = with lib; {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "asciinema-player packaged for setuptools (easy_install) / pip.";
    homepage = "https://github.com/asciinema/asciinema-player";
    license = with licenses; [ asl20 ];
  };
}
