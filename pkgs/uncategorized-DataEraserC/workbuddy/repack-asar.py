#!/usr/bin/env python3
"""Minimal asar re-packer for the workbuddy Nix package.

Replaces one file (main/index.js) inside app.asar so that BrowserWindow
calls show() at the top of the ready-to-show handler, fixing a Wayland/
waypipe deadlock where ready-to-show never fires.

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
        f0, f1, f2, n = struct.unpack("<4I", f.read(16))
        header = json.loads(f.read(n).decode("utf-8"))
        pad = f1 - 8 - n
        data_start = 8 + f1
        f.seek(data_start)
        payload = f.read()
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
            meta["size"] = str(len(data))
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

    The fix adds show() at the top of the ready-to-show handler, before
    the existing show() call at the bottom. On X11 this is a no-op because
    ready-to-show fires normally and the window is already visible.
    """
    old = (
        '\t\tmainWindow.once("ready-to-show", () => {\n'
        "\t\t\tif (mainWindow.isDestroyed()) {\n"
        '\t\t\t\trequire_log_acl_guard.windowLog.info("[WindowManager] '
        'ready-to-show arrived after window destroyed, skipping");\n'
        "\t\t\t\treturn;\n"
        "\t\t\t}"
    )
    new = (
        '\t\tmainWindow.once("ready-to-show", () => {\n'
        "\t\t\tif (mainWindow.isDestroyed()) {\n"
        '\t\t\t\trequire_log_acl_guard.windowLog.info("[WindowManager] '
        'ready-to-show arrived after window destroyed, skipping");\n'
        "\t\t\t\treturn;\n"
        "\t\t\t}\n"
        "\t\t\t// [nixos-patch] Wayland/waypipe fix: ready-to-show may not fire\n"
        "\t\t\t// because first-paint needs a surface commit, but the surface\n"
        "\t\t\t// isn't shown until show(). Break the deadlock by calling\n"
        "\t\t\t// show() here even though the normal show() is below.\n"
        "\t\t\ttry { if (!mainWindow.isVisible()) mainWindow.show(); } catch(e) {}"
    )
    count = orig_bytes.count(old.encode("utf-8"))
    if count != 1:
        raise SystemExit(
            f"wayland-show-fix: expected 1 occurrence of the anchor, found {count}"
        )
    return orig_bytes.replace(old.encode("utf-8"), new.encode("utf-8"))


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
    Path(asar_out).write_bytes(out)
    print(f"Repacked asar: {len(out)} bytes -> {asar_out}", file=sys.stderr)


if __name__ == "__main__":
    main()
