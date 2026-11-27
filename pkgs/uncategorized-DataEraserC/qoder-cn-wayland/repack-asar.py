#!/usr/bin/env python3
"""Add a ready-to-show fallback to qoder-cn's app.asar.

qoder-cn creates its main window with `show:false` and only calls show() from
the `ready-to-show` callback. On Wayland/waypipe the window is never mapped,
so it never paints a first frame, `ready-to-show` stays silent, and the app
looks hung with no window. Schedule a 1.5 s fallback show() before the
callback; when `ready-to-show` fires normally the timer is a no-op.

Usage: repack-asar.py <asar_path>
The file is patched in place. The build fails if the anchor is missing or
appears more than once, so an upstream version bump cannot silently drop the
fix.
"""

import hashlib
import json
import struct
import sys
from pathlib import Path

TARGET = "out/main/electronMain.js"
ANCHOR = 'm.once("ready-to-show",()=>{const z=Date.now();'
PATCH = (
    "setTimeout(()=>{m.isDestroyed()||m.isVisible()||"
    "(nI?.placeForInitialShow(m),m.show())},1500),"
)
# If upstream starts shipping its own fallback, stop patching and say so.
UPSTREAM_MARKERS = ("ready-to-show-timeout", "InitialRevealGate")


def read_asar_bytes(body):
    f0, f1, f2, n = struct.unpack("<4I", body[:16])
    header = json.loads(body[16 : 16 + n].decode("utf-8"))
    return header, body[8 + f1 :], (f0, f1, f2, n)


def walk(node, prefix=""):
    for name, meta in node.get("files", {}).items():
        cur = f"{prefix}/{name}" if prefix else name
        if "files" in meta:
            yield from walk(meta, cur)
        else:
            yield cur, meta


def read_entry(header, payload, want):
    for asar_path, meta in walk(header):
        if asar_path == want and not meta.get("unpacked"):
            off = int(meta["offset"])
            return meta, payload[off : off + int(meta["size"])]
    return None, None


def rebuild(header, payload, replace):
    entries = list(walk(header))
    entries.sort(key=lambda kv: int(kv[1].get("offset", 0)))
    chunks = []
    cursor = 0
    for asar_path, meta in entries:
        if meta.get("unpacked"):
            if asar_path in replace:
                raise SystemExit(f"cannot patch unpacked file: {asar_path}")
            continue
        if asar_path in replace:
            data = replace[asar_path]
            # Electron's asar reader requires `size` to be an int and
            # `offset` a decimal string; swapping the types makes the entry
            # unreadable even though the bytes and hashes look correct.
            meta["size"] = len(data)
            digest = hashlib.sha256(data).hexdigest()
            meta["integrity"] = {
                "algorithm": "SHA256",
                "hash": digest,
                "blockSize": 4194304,
                "blocks": [digest],
            }
        else:
            off = int(meta["offset"])
            data = payload[off : off + int(meta["size"])]
        meta["offset"] = str(cursor)
        cursor += len(data)
        chunks.append(data)

    body = json.dumps(header, separators=(",", ":")).encode("utf-8")
    n = len(body)
    pad = (4 - ((8 + n) % 4)) % 4
    hsize = 8 + n + pad
    return (
        struct.pack("<4I", 4, hsize, hsize - 4, n)
        + body
        + b"\x00" * pad
        + b"".join(chunks)
    )


def verify_types(orig_header, new_header):
    old = dict(walk(orig_header))
    new = dict(walk(new_header))
    if set(old) != set(new):
        raise SystemExit("entry set changed across rebuild")
    for path, meta in new.items():
        for key in old[path]:
            if type(old[path][key]) is not type(meta[key]):
                raise SystemExit(
                    f"metadata type drift for {path} {key}: "
                    f"{type(old[path][key]).__name__} -> {type(meta[key]).__name__}"
                )


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <asar_path>")
    path = Path(sys.argv[1])
    body = path.read_bytes()
    header, payload, _ = read_asar_bytes(body)
    _, content = read_entry(header, payload, TARGET)
    if content is None:
        raise SystemExit(f"{TARGET} not found in {path}")

    text = content.decode("utf-8")
    for marker in UPSTREAM_MARKERS:
        if marker in text:
            print(
                f"wayland-show-fix: upstream fallback marker {marker!r} present, "
                "asar left unchanged",
                file=sys.stderr,
            )
            return

    count = text.count(ANCHOR)
    if count != 1:
        raise SystemExit(
            f"wayland-show-fix: expected 1 occurrence of the anchor, found {count}; "
            "re-check the patch for this qoder version"
        )

    patched = text.replace(ANCHOR, PATCH + ANCHOR).encode("utf-8")
    print(
        f"wayland-show-fix: {TARGET} {len(content)} -> {len(patched)} bytes",
        file=sys.stderr,
    )

    out = rebuild(header, payload, {TARGET: patched})
    new_header, _, _ = read_asar_bytes(out)
    verify_types(header, new_header)
    path.write_bytes(out)
    print(
        f"wayland-show-fix: wrote {path} ({len(out)} bytes, "
        f"{len(dict(walk(new_header)))} entries)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
