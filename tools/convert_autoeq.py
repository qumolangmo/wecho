#!/usr/bin/env python3
"""Convert the AutoEq CSV assets into a single binary blob plus a Dart const index.

Input : android/app/src/main/assets/output_csv/index.tsv + referenced CSV files
        (columns: frequency,raw,smoothed,error,equalization)
Output: native/data/autoeq.bin   (embedded into libwecho.so at build time)
        lib/models/autoeq_index.dart

Binary layout: raw payload only, no header. Devices are concatenated in
index.tsv order; each device holds <rowCount> rows of 3 x float16
(frequency, equalization, error), little-endian (~0.008 dB quantization on
gains, negligible on the frequency axis).

dataOffset in the Dart index is the absolute byte offset of the device's
payload inside autoeq.bin; native code indexes the embedded blob at that
offset and reads rowCount * 6 bytes. The index itself lives as a generated
Dart const list.
"""

import json
import os
import struct
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_DIR = os.path.join(PROJECT_ROOT, "android", "app", "src", "main", "assets", "output_csv")
BIN_OUT = os.path.join(PROJECT_ROOT, "native", "data", "autoeq.bin")
DART_OUT = os.path.join(PROJECT_ROOT, "lib", "models", "autoeq_index.dart")

DART_TEMPLATE = """// GENERATED FILE - do not edit manually.
// Regenerate with: python tools/convert_autoeq.py
//
// One entry per AutoEq measurement. [rigId] and [typeId] index into the
// deduplicated tables below. [dataOffset] is the absolute byte offset of the
// device's payload inside the raw data blob (3 x float16 per row) embedded
// in libwecho.so / apo.dll; each payload holds [rowCount] rows.

/// Rig IDs, shared by all entries to keep the table compact.
const List<String> kAutoEqRigs = <String>{rigs};

/// Type IDs (in-ear / over-ear / earbud).
const List<String> kAutoEqTypes = <String>{types};

class AutoEqEntry {
  const AutoEqEntry(
    this.name,
    this.rigId,
    this.typeId,
    this.dataOffset,
    this.rowCount,
  );

  final String name;
  final int rigId;
  final int typeId;
  final int dataOffset;
  final int rowCount;
}

/// Device count: {count}
const List<AutoEqEntry> kAutoEqIndex = <AutoEqEntry>[
{entries}
];
"""


def dart_str(s: str) -> str:
    """Dart string literal; JSON escaping is a compatible subset."""
    return json.dumps(s, ensure_ascii=False)


def main() -> int:
    index_path = os.path.join(CSV_DIR, "index.tsv")
    entries = []
    rigs: dict[str, int] = {}
    types: dict[str, int] = {}

    with open(index_path, encoding="utf-8") as f:
        f.readline()  # header row
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 6:
                continue
            name, filepath, _source, rig, typ, _channels = parts[:6]
            entries.append((name, filepath, rig, typ))

    rig_names = sorted({rig for _, _, rig, _ in entries})
    rig_ids = {rig: i for i, rig in enumerate(rig_names)}
    type_ids = {}
    for _, _, _, typ in entries:
        if typ not in type_ids:
            type_ids[typ] = len(type_ids)

    total_rows = 0
    payload = bytearray()
    dart_entries = []
    os.makedirs(os.path.dirname(BIN_OUT), exist_ok=True)
    with open(BIN_OUT, "wb") as bin_out:
        for name, filepath, rig, typ in entries:
            rows = []
            with open(os.path.join(CSV_DIR, filepath.replace("/", os.sep)), encoding="utf-8-sig") as g:
                headers = g.readline().strip().split(",")
                if headers != ["frequency", "raw", "smoothed", "error", "equalization"]:
                    raise ValueError(f"unexpected header in {filepath}: {headers}")
                for row in g:
                    cols = row.strip().split(",")
                    if len(cols) != len(headers):
                        continue
                    rows.append((float(cols[0]), float(cols[4]), float(cols[3])))

            offset = len(payload)
            for freq, eq, err in rows:
                payload += struct.pack("<3e", freq, eq, err)

            dart_entries.append(
                "  AutoEqEntry({}, {}, {}, {}, {}),".format(
                    dart_str(name), rig_ids[rig], type_ids[typ], offset, len(rows)
                )
            )
            total_rows += len(rows)

        bin_out.write(payload)

    os.makedirs(os.path.dirname(DART_OUT), exist_ok=True)
    with open(DART_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            DART_TEMPLATE
            .replace("{rigs}", json.dumps(rig_names, ensure_ascii=False))
            .replace("{types}", json.dumps(sorted(type_ids, key=type_ids.get), ensure_ascii=False))
            .replace("{count}", str(len(entries)))
            .replace("{entries}", "\n" + "\n".join(dart_entries) + "\n")
        )

    size = len(payload)
    print(f"devices : {len(entries)}")
    print(f"rows    : {total_rows}")
    print(f"bin size: {size / 1024 / 1024:.1f} MB -> {BIN_OUT}")
    print(f"dart out: {DART_OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
