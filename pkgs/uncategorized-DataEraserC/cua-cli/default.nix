# cua-cli — the `cua` command-line interface (sandbox engine + MCP server).
#
# Prebuilt upstream binaries from the cua-sdk-v* GitHub releases — no Rust
# toolchain build. The linux-x64 tarball is a single dynamically linked ELF
# whose NEEDED set is glibc + libgcc_s only (no symbol newer than GLIBC_2.30),
# so autoPatchelfHook with the toolchain's libgcc is the entire rewrap it
# needs on NixOS.
#
# Ships the version-matched agent skills (cua-sandboxes, gui-automation) under
# share/cua-skills. Upstream publishes no skills asset with the CLI release,
# so the three files are fetched from the source tree at the same tag. dsh
# links them into $DSH_HOME/skills (dsh is absent from the CLI's own
# `cua skills install` agent list).
#
# What this binary is for: `cua mcp` exposes the sandbox surface —
# sandbox_create/list/start/stop/... plus computer_* desktop control of the
# sandbox named per call — driving a disposable container "computer" (Podman /
# Docker via cua-vmm), NOT the host session. Controlling this machine's own
# desktop is cua-driver's job (see the sibling package).
{
  lib,
  fetchurl,
  stdenv,
  autoPatchelfHook,
}:
let
  versionData = {
    tag = "cua-sdk-v0.9.0";
    hash = "sha256-l4Af9MOqLz2Z+POa4tCHldzOwkFZOrN0vnypJXYUIco=";
  };
  version = lib.removePrefix "cua-sdk-v" versionData.tag;
  # Same tag as the binary: the skills describe the CLI's own commands, so a
  # tag skew would teach the model flags this build does not have.
  skillUrl =
    name: "https://raw.githubusercontent.com/trycua/cua/${versionData.tag}/libs/cua/skills/${name}";
  skills = {
    "cua-sandboxes/SKILL.md" = fetchurl {
      url = skillUrl "cua-sandboxes/SKILL.md";
      hash = "sha256-6VKoWQpJzh9dKRwhyRI9IzkhzU4IlRKkwqjSxAcZAHw=";
    };
    "gui-automation/SKILL.md" = fetchurl {
      url = skillUrl "gui-automation/SKILL.md";
      hash = "sha256-k0kEp4v+vBuqFA2/1I8XNPxOSWR5s4OqtU8mZyQzvLw=";
    };
    "gui-automation/references/command-reference.md" = fetchurl {
      url = skillUrl "gui-automation/references/command-reference.md";
      hash = "sha256-BKuXr6lAJ1xiZ4ztdsiFJpFEzjXdootN/QY+3KEE/VM=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "cua-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/trycua/cua/releases/download/${versionData.tag}/cua-cli-${version}-linux-x64.tar.gz";
    hash = versionData.hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # The tarball holds the `cua` binary (plus, since cua-sdk-v0.9.0, the
  # sandbox engine binaries); unpack it explicitly instead of relying on
  # extension sniffing through fetchurl.
  unpackPhase = ''
    runHook preUnpack
    tar xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Since cua-sdk-v0.9.0 the tarball also ships the sandbox engine
    # binaries (cua-microvm-init, cua-spacesd-linux-x86_64) that the
    # sandbox_* lifecycle tools spawn, so keep every executable —
    # autoPatchelfHook rewraps all of them alike.
    for bin in cua cua-microvm-init cua-spacesd-*; do
      if [ -e "$bin" ]; then
        install -Dm755 "$bin" "$out/bin/$bin"
      fi
    done

    install -Dm644 ${skills."cua-sandboxes/SKILL.md"} \
      $out/share/cua-skills/cua-sandboxes/SKILL.md
    install -Dm644 ${skills."gui-automation/SKILL.md"} \
      $out/share/cua-skills/gui-automation/SKILL.md
    install -Dm644 ${skills."gui-automation/references/command-reference.md"} \
      $out/share/cua-skills/gui-automation/references/command-reference.md

    runHook postInstall
  '';

  postInstall = ''
    test -x $out/bin/cua
    test -f $out/share/cua-skills/cua-sandboxes/SKILL.md
    test -f $out/share/cua-skills/gui-automation/SKILL.md
    test -f $out/share/cua-skills/gui-automation/references/command-reference.md
  '';

  # Smoke-test the patched binary in its own output check (fixupPhase has
  # already swapped the interpreter by then; inside postInstall the build
  # sandbox still lacks /lib64/ld-linux-x86-64.so.2).
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/cua --version
    runHook postInstallCheck
  '';

  passthru = {
    aiProvenance = [
      {
        agent = "workbuddy";
        model = "step-5-preview";
        involvement = "authored";
      }
    ];
    # The releases atom feed is flooded with nightly-*/cua-spaces-* tags and
    # the version lives in versionData.tag, so nix-update cannot drive this
    # package; see update.sh.
    updateScript = [ (toString ./update.sh) ];
  };

  meta = {
    description = "CLI for the Cua computer-use stack: sandbox lifecycle (Podman/Docker/QEMU/Lume) and its MCP server";
    homepage = "https://github.com/trycua/cua";
    changelog = "https://github.com/trycua/cua/releases?q=cua-sdk";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    mainProgram = "cua";
    # Prebuilt x86_64-linux asset only; aarch64 has its own release tarball
    # (cua-cli-<version>-linux-arm64.tar.gz) if a future need appears.
    platforms = [ "x86_64-linux" ];
  };
}
