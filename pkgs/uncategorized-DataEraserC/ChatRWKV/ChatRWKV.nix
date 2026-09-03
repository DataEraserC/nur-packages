# https://github.com/nixified-ai/flake/blob/63339e4c8727578a0fe0f2c63865f60b6e800079/packages/rwkv/default.nix#L9
{
  lib,
  python3Packages,
  buildPythonPackage ? python3Packages.buildPythonPackage,
  setuptools ? python3Packages.setuptools,
  tokenizers ? python3Packages.tokenizers,
  fetchurl,
}:
let
  version = "0.8.32";

  src = fetchurl {
    url = "https://pypi.org/packages/source/r/rwkv/rwkv-${version}.tar.gz";
    hash = "sha256-p5QfONQKVc+004zucsVyumXrL2MUmI1cJWhBGqztgDE=";
  };
in
buildPythonPackage rec {
  pname = "rwkv";
  inherit version src;
  format = "pyproject";

  passthru.updateScript = [ (toString ./update.sh) ];

  propagatedBuildInputs = [
    setuptools
    tokenizers
  ];

  pythonImportsCheck = [ "rwkv" ];

  meta = with lib; {
    description = "The RWKV Language Model";
    homepage = "https://github.com/BlinkDL/ChatRWKV";
    license = licenses.asl20;
    maintainers = with maintainers; [ jpetrucciani ];
  };
}
