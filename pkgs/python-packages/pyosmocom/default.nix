{
  fetchgit,
  lib,
  buildPythonPackage,
  # Dependencies
  unstableGitUpdater,
  setuptools,
  construct,
  gsm0338,
}:
buildPythonPackage (finalAttrs: {
  pname = "pyosmocom";
  version = "0.0.12-unstable-2026-11-26";
  pyproject = true;

  src = fetchgit {
    url = "https://gitea.osmocom.org/osmocom/pyosmocom.git";
    rev = "bbc21debbab70e39ad8609033cd5861cd255af35";
    fetchSubmodules = false;
    hash = "sha256-RR2gRLwBIYuD1huVXZsjdlkLETXXI9zfEp50CRrcVT4=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  build-system = [ setuptools ];
  dependencies = [
    construct
    gsm0338
  ];

  pythonImportsCheck = [ "osmocom" ];

  passthru.updateScript = unstableGitUpdater {
    url = "https://gitea.osmocom.org/osmocom/pyosmocom.git";
  };
  meta = {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Python implementation of key Osmocom protocols/interfaces";
    homepage = "https://gitea.osmocom.org/osmocom/pyosmocom";
    license = with lib.licenses; [ gpl2Only ];
  };
})
