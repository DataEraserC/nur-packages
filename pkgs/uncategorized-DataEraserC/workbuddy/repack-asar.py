#!/usr/bin/env python3
"""Minimal asar re-packer for the workbuddy Nix package.

Replaces one file (main/index.js) inside app.asar so that the main window is
shown on a fallback timer instead of waiting only for `ready-to-show`, which
can stay silent forever on Wayland/waypipe and leaves the app running with no
visible window.

The repack preserves asar structure (header + payload), recalculates
offsets/sizes/integrity hashes for all entries, and keeps the original
physical file order so unrelated files stay at their relative positions.

Usage:
    repack-asar.py <asar_path> <output_path>

The patch is applied in installPhase, not as a Nix patchPhase, because
the asar is a single binary blob that can't be patched with standard
Nix patch tools.
"""

import hashlib
import json
import struct
import sys
from pathlib import Path


def read_asar(path: str):
    """Read asar header + payload from a file path."""
    with open(path, "rb") as f:
        body = f.read()
    return read_asar_bytes(body)


def read_asar_bytes(body: bytes):
    """Read asar header + payload from already-loaded bytes."""
    f0, f1, f2, n = struct.unpack("<4I", body[:16])
    header = json.loads(body[16 : 16 + n].decode("utf-8"))
    pad = f1 - 8 - n
    data_start = 8 + f1
    payload = body[data_start:]
    return header, payload, (f0, f1, f2, n, pad, data_start)


def walk(node, prefix=""):
    """Yield (path, meta) for every file in the asar header tree."""
    for name, meta in node.get("files", {}).items():
        cur = f"{prefix}/{name}" if prefix else name
        if "files" in meta:
            yield from walk(meta, cur)
        else:
            yield cur, meta


def rebuild(header, payload, origin, replace=None):
    """Rebuild asar with optional file replacements.

    replace: {path: new_bytes}. Rewrites offsets/sizes/integrity, keeps order.
    """
    entries = list(walk(header))
    # Keep the original physical order so unrelated files stay at their offsets.
    entries.sort(key=lambda kv: int(kv[1].get("offset", 0)))
    chunks = []
    cursor = 0
    for asar_path, meta in entries:
        if meta.get("unpacked"):
            if replace and asar_path in replace:
                raise SystemExit(f"cannot patch unpacked file: {asar_path}")
            continue
        if replace and asar_path in replace:
            data = replace[asar_path]
            # `size` is an integer in the Chromium asar reader, while `offset`
            # is a decimal string. Writing size as a string makes Electron
            # treat the entry as unreadable: "Cannot find module
            # .../app.asar/main/index.js".
            meta["size"] = len(data)
            h = hashlib.sha256(data).hexdigest()
            meta["integrity"] = {
                "algorithm": "SHA256",
                "hash": h,
                "blockSize": 4194304,
                "blocks": [h],
            }
        else:
            off = int(meta["offset"])
            data = payload[off : off + int(meta["size"])]
        meta["offset"] = str(cursor)
        cursor += len(data)
        chunks.append(data)
    new_payload = b"".join(chunks)
    body = json.dumps(header, separators=(",", ":")).encode("utf-8")
    n = len(body)
    pad = (4 - ((8 + n) % 4)) % 4
    hsize = 8 + n + pad
    header_bytes = struct.pack("<4I", 4, hsize, hsize - 4, n) + body + b"\x00" * pad
    return header_bytes + new_payload


def apply_wayland_patch(orig_bytes: bytes) -> bytes:
    """Apply the Wayland show() fix to main/index.js content.

    The main window is created with `show: false` and upstream only calls
    show() from the `ready-to-show` callback. That callback is emitted after
    the first frame, but on Wayland/waypipe a window that was never mapped
    does not produce one, so the event can stay silent forever and the app
    looks hung with no window at all.

    Adding show() inside the `ready-to-show` handler does not help: the
    handler is exactly what never runs. The fix instead schedules a fallback
    show() right after window creation. Locally `ready-to-show` arrives well
    within the timeout, so the timer finds the window already visible and
    does nothing; under waypipe it is what surfaces the window.
    """
    old = '\t\trequire_log_acl_guard.windowLog.info("[WindowManager] Window created");'
    new = (
        old + "\n"
        "\t\t// [nixos-patch] Wayland/waypipe: `ready-to-show` can stay silent\n"
        "\t\t// because the window is never mapped, so it never paints a first\n"
        "\t\t// frame. Show it on a timer; the normal path is a no-op when\n"
        "\t\t// `ready-to-show` fired first.\n"
        "\t\tsetTimeout(() => {\n"
        "\t\t\tif (this.mainWindow && !this.mainWindow.isDestroyed() && !this.mainWindow.isVisible()) {\n"
        '\t\t\t\trequire_log_acl_guard.windowLog.info("[WindowManager] [nixos-patch] ready-to-show timeout, showing window");\n'
        "\t\t\t\tthis.mainWindow.show();\n"
        "\t\t\t}\n"
        "\t\t}, 1000).unref?.();"
    )
    count = orig_bytes.count(old.encode("utf-8"))
    if count != 1:
        raise SystemExit(
            f"wayland-show-fix: expected 1 occurrence of the anchor, found {count}"
        )
    return orig_bytes.replace(old.encode("utf-8"), new.encode("utf-8"))


def verify_types(orig_header, new_header):
    """Fail loudly if rebuilding changed the JSON type of any metadata field.

    Electron's asar reader is strict about `size` being an integer and
    `offset` a string; a silent type change makes the entry unreadable at
    runtime ("Cannot find module .../app.asar/main/index.js") while the
    bytes and hashes still look correct. This check is what catches that.
    """
    orig_entries = dict(walk(orig_header))
    new_entries = dict(walk(new_header))
    if set(orig_entries) != set(new_entries):
        raise SystemExit("verify: entry set changed across rebuild")

    problems = []
    for path, new_meta in new_entries.items():
        orig_meta = orig_entries[path]
        if set(orig_meta) != set(new_meta):
            problems.append(f"{path}: keys {sorted(orig_meta)} -> {sorted(new_meta)}")
            continue
        for key in orig_meta:
            if type(orig_meta[key]) is not type(new_meta[key]):
                problems.append(
                    f"{path}: {key} {type(orig_meta[key]).__name__}"
                    f" -> {type(new_meta[key]).__name__}"
                )
    if problems:
        raise SystemExit(
            "verify: metadata type drift:\n  " + "\n  ".join(problems[:20])
        )


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.asar> <output.asar>", file=sys.stderr)
        sys.exit(1)

    asar_in = sys.argv[1]
    asar_out = sys.argv[2]

    header, payload, origin = read_asar(asar_in)

    # Find main/index.js in the asar and patch it.
    patched_js = None
    for asar_path, meta in walk(header):
        if asar_path == "main/index.js" and not meta.get("unpacked"):
            off = int(meta["offset"])
            orig_js = payload[off : off + int(meta["size"])]
            # Verify integrity
            orig_hash = meta["integrity"]["hash"]
            actual_hash = hashlib.sha256(orig_js).hexdigest()
            if actual_hash != orig_hash:
                raise SystemExit(
                    f"integrity mismatch for main/index.js: "
                    f"header={orig_hash} actual={actual_hash}"
                )
            patched_js = apply_wayland_patch(orig_js)
            print(
                f"Patched main/index.js: {len(orig_js)} -> {len(patched_js)} bytes",
                file=sys.stderr,
            )
            break

    if patched_js is None:
        raise SystemExit("main/index.js not found in asar")

    out = rebuild(header, payload, origin, replace={"main/index.js": patched_js})

    # Re-read what we are about to write and prove the header still carries
    # the original field types; a repacked asar that Electron cannot read
    # would otherwise only fail at app start-up.
    new_header, _, _ = read_asar_bytes(out)
    verify_types(header, new_header)

    Path(asar_out).write_bytes(out)
    print(
        f"Repacked asar: {len(out)} bytes, {len(dict(walk(new_header)))} entries "
        f"(types verified) -> {asar_out}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
