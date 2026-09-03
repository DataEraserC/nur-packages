{
  fetchFromGitHub,
  lib,
  unstableGitUpdater,
  python3Packages,
}:
python3Packages.buildPythonApplication rec {
  pname = "open-interpreter";
  version = "unstable-2026-08-19";

  src = fetchFromGitHub {
    owner = "OpenInterpreter";
    repo = "open-interpreter";
    rev = "5b07159c477920c159d8892d112b480e7307f257";
    hash = "sha256-sdYloCCBNPut67p6HYjUHLCdt0JGnHBMD/UDpplevus=";
    fetchSubmodules = true;
  };

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/OpenInterpreter/open-interpreter";
  };

  pyproject = true;

  propagatedBuildInputs = with python3Packages; [
    html2image
    html2text
    inquirer
    ipykernel
    jupyter-client
    litellm
    matplotlib
    nltk
    platformdirs
    psutil
    pydantic
    pyperclip
    pyyaml
    selenium
    send2trash
    setuptools
    shortuuid
    starlette
    tiktoken
    tokentrim
    toml
    webdriver-manager
    wget
    yaspin
    anthropic
    astor
    google-generativeai
    rich
    typer
  ];

  build-system = [ python3Packages.poetry-core ];

  meta = {
    description = "A natural language interface for computers";
    homepage = "https://github.com/OpenInterpreter/open-interpreter";
    license = lib.licenses.agpl3Only;
    mainProgram = "interpreter";
    broken = true;
  };
}
