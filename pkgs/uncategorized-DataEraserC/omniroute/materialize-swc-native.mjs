// Invoked as `node materialize-swc-native.mjs <node_modules>...` from postConfigure.
//
// @swc/core >= 1.16.13 ships its platform addon as a zstd-compressed "carrier":
// the first require() materializes the real addon into a cache root, and the
// loader refuses any root whose ancestors are writable by another user. That
// check cannot be satisfied inside the Nix build sandbox (the sandbox root is
// owned by nobody and only group-writable), so the carrier is decompressed here
// and written back over itself before anything requires it.
//
// The payload layout is the SWCNZSTD header documented in swc's
// docs/native-addon-carriers.md: a 96-byte header followed by one zstd frame
// that decodes to the stripped addon.
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { zstdDecompressSync } from "node:zlib";

const CARRIER_MAGIC = "SWCNZSTD";
const ZSTD_MAGIC = 0xfd2fb528;

function findCarrier(buf) {
  for (let i = buf.indexOf(CARRIER_MAGIC); i >= 0; i = buf.indexOf(CARRIER_MAGIC, i + 1)) {
    if (i + 12 > buf.length) continue;
    const headerSize = buf.readUInt16LE(i + 10);
    if (i + headerSize + 4 > buf.length) continue;
    if (buf.readUInt32LE(i + headerSize) === ZSTD_MAGIC) return i;
  }
  return -1;
}

function materialize(path) {
  const buf = readFileSync(path);
  const marker = findCarrier(buf);
  if (marker < 0) return null;
  const headerSize = buf.readUInt16LE(marker + 10);
  const rawLength = Number(buf.readBigUInt64LE(marker + 24));
  const raw = zstdDecompressSync(buf.subarray(marker + headerSize));
  if (raw.length !== rawLength) {
    throw new Error(`${path}: decoded ${raw.length} bytes, header declares ${rawLength}`);
  }
  writeFileSync(path, raw);
  return raw.length;
}

const roots = process.argv.slice(2);
let converted = 0;
for (const root of roots) {
  const dir = join(root, "@swc");
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    continue;
  }
  for (const entry of entries) {
    if (!entry.startsWith("core-")) continue;
    const dirPath = join(dir, entry);
    if (!statSync(dirPath).isDirectory()) continue;
    for (const file of readdirSync(dirPath)) {
      if (!file.endsWith(".node")) continue;
      const size = materialize(join(dirPath, file));
      if (size !== null) {
        console.log(`[materialize-swc] ${entry}/${file}: ${size} bytes`);
        converted += 1;
      }
    }
  }
}
if (converted === 0) console.log("[materialize-swc] no compressed carriers found");
