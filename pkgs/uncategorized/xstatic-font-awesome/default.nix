{
  lib,
  sources,
  python3Packages,
  ...
}:
with python3Packages;
buildPythonPackage rec {
  inherit (sources.xstatic-font-awesome) pname version src;

  meta = with lib; {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Font Awesome packaged for setuptools (easy_install) / pip.";
    homepage = "https://github.com/FortAwesome/Font-Awesome";
    license = with licenses; [ ofl ];
  };
}
