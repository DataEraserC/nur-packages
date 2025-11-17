# https://github.com/nixified-ai/flake/blob/63339e4c8727578a0fe0f2c63865f60b6e800079/packages/rwkv/default.nix#L9
{
  lib,
  python3Packages,
  buildPythonPackage ? python3Packages.buildPythonPackage,
  setuptools ? python3Packages.setuptools,
  tokenizers ? python3Packages.tokenizers,
  sources,
}:
buildPythonPackage rec {
  inherit (sources.AAA_rwkv) pname version src;
  format = "pyproject";

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
