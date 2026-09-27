#!/usr/bin/env python3
"""Generate @deepseek-ai/dsh-agent-preset rows from the preset tree.

Run by the installPhase after presetDir is populated and cordis.patch.yml is
copied into place; replaces the ``# @GENERATED_PRESETS@`` marker inside the
template's insert block with one declaration per <presetDir>/*/preset.yml.
Single source of truth: upstream qq-bridge dsh/agent-presets (version bumps
flow through automatically).

Usage: generate-preset-rows.py <presetDir> <patchFile>

No PyYAML: preset.yml carries three plain scalars (first-colon split,
BOM-safe, quote-stripped); agent.cordis.yml is shifted as text so comments,
block scalars and quoting survive verbatim.
"""

import os
import re
import sys


def scalars(path):
    out = {}
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            key, sep, value = line.partition(":")
            if not sep:
                raise SystemExit(f"{path}: unparsable line {line!r}")
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            out[key.strip()] = value
    return out


def plugin_rows(path, pid, preset_dir):
    with open(path, encoding="utf-8-sig") as fh:
        lines = fh.read().splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("- ")), None)
    if start is None:
        raise SystemExit(f"{path}: no rows found")
    out = []
    for line in lines[start:]:
        match = re.match(r"^(\s*)name: (\./\S+)\s*$", line)
        if match:
            target = f"{preset_dir}/{pid}/{match.group(2)[2:]}"
            if not os.path.isfile(target):
                raise SystemExit(f"missing plugin file: {target}")
            line = f"{match.group(1)}name: '{target}'"
        out.append("          " + line if line.strip() else "")
    return out


def quote(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    preset_dir, patch_file = sys.argv[1], sys.argv[2]
    pids = sorted(
        entry
        for entry in os.listdir(preset_dir)
        if os.path.isfile(os.path.join(preset_dir, entry, "preset.yml"))
    )
    if not pids:
        raise SystemExit(f"no presets with preset.yml under {preset_dir}")
    blocks = []
    for pid in pids:
        meta = scalars(os.path.join(preset_dir, pid, "preset.yml"))
        for field in ("name", "description", "order"):
            if field not in meta:
                raise SystemExit(f"{pid}/preset.yml: missing {field}")
        try:
            order = int(meta["order"])
        except ValueError:
            raise SystemExit(
                f"{pid}/preset.yml: order not an integer: {meta['order']!r}"
            )
        agent = os.path.join(preset_dir, pid, "agent.cordis.yml")
        if not os.path.isfile(agent):
            raise SystemExit(f"{pid}: missing agent.cordis.yml")
        rows = plugin_rows(agent, pid, preset_dir)
        blocks.append(
            "\n".join(
                [
                    f"    # preset-{pid}: generated at build time from {preset_dir}/{pid}",
                    f"    - id: preset-{pid}",
                    "      name: '@deepseek-ai/dsh-agent-preset'",
                    "      config:",
                    f"        id: {pid}",
                    f"        name: {quote(meta['name'])}",
                    f"        description: {quote(meta['description'])}",
                    f"        order: {order}",
                    "        plugins:",
                    *rows,
                ]
            )
        )
    with open(patch_file, encoding="utf-8") as fh:
        text = fh.read()
    marker = "    # @GENERATED_PRESETS@"
    if text.count(marker) != 1:
        raise SystemExit(f"marker count is {text.count(marker)}, expected exactly 1")
    with open(patch_file, "w", encoding="utf-8") as fh:
        fh.write(text.replace(marker, "\n".join(blocks)))
    print(f"generated preset declarations for: {', '.join(pids)}")


if __name__ == "__main__":
    main()
