{
  lib,
  sources,
  python3Packages,
}:
python3Packages.buildPythonApplication rec {
  inherit (sources.open-interpreter) pname version src;
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
