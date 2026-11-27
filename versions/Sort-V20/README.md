# Sort-V20 - raw device scanning (--scan-raw)

V20 adds `--scan-raw`: signature-based scanning of a **raw block device or
disk image** (`--scan-raw /dev/sdb`, `--scan-raw disk.img`). The 237-entry
magic table already used by `--magic` is reused to find known file formats
at **any byte offset**, including files that are no longer reachable through
the filesystem (lost data, deleted files, damaged partitions).

## The six files

| File | Edition |
|---|---|
| `Sort-V20.sh` | Bash edition (self-contained, threaded) |
| `Sort-V20.pas` | FreePascal translation (`fpc -Mobjfpc -Sh Sort-V20.pas`) |
| `Sort-V20.py` | Python edition, stdlib only, era-gated |
| `Sort-V20.cpp` | C++17 CLI edition, no dependencies |
| `Sort-GUI.cpp` | C++17 + Qt6/QML GUI edition (V20 engine, scan-raw row added) |

## What is new in V20

* `--scan-raw PATH` (or `--scan-raw=PATH`), in every edition including the GUI:
  * reads the device/image in 1 MiB blocks (with carry for signatures that
    straddle block boundaries), tests every offset against the 237 known
    signatures (short/wildcard signatures are anchored on their longest
    fixed run)
  * format end rules: PNG chunk walk (IEND = exact), JPEG to FFD9, GIF to
    0x3B, ZIP to the EOCD record, PDF to %%EOF; everything else is a
    capped guess (default cap 5 MiB) and marked as such
  * overlap suppression: an exact fragment owns its byte range; capped
    guesses only suppress at the same offset
  * dummy mode (default): report only. copy mode: carves each fragment to
    `Target/RAW-CARVE/<12-digit-hex-offset>.<ext>`
  * refuses move/remove/trash/shred with
    `RAW-SCAN: --scan-raw supports dummy and copy only (mode 'X' refused)`,
    exit code 64; the scan itself is read-only on the source device
  * JSONL log entry per carved fragment: `{"action": "carved",
    "src": "device@offset", "dst": ...}`; `--undo` deletes the carved
    fragments (carved data never goes back into the image)
* Output format is identical in all editions:
  `RAW-SCAN: <path>`, `  hit: 0x<12-digit-offset> <offset> <format> -> <ext>
  (carve N bytes[, capped])`, `  carved: <path>` (copy only),
  `RAW-SCAN: N signatures found`
* Version bump: all editions re-badged from 19 to 20; the Qt6 GUI gains a
  `--scan-raw` row (device/image path + Scan raw button).

## Safety notes

* The source device is opened **read-only**; nothing is ever written to it.
* Destructive modes are refused (exit 64): scanning never deletes.
* Running raw devices usually needs root (`sudo ./Sort --scan-raw /dev/sdb`).
* The Bash edition is noticeably slower on large drives (it is pure shell);
  for real disks use the C++ edition (`Sort.cpp`).

## Build and run (Debian)

```
# C++ CLI (recommended for whole drives)
g++ -std=c++17 -O2 -pthread -o Sort Sort-V20.cpp
sudo ./Sort --scan-raw /dev/sdb                 # report only
sudo ./Sort --mode=copy --target=/tmp/rescued --log=act.jsonl --scan-raw /dev/sdb

# Pascal
fpc -Mobjfpc -Sh Sort-V20.pas

# Python
python3 Sort-V20.py --scan-raw disk.img

# Bash
bash Sort-V20.sh --scan-raw disk.img

# Qt6 GUI (scan-raw row in the window)
moc Sort-GUI.cpp -o Sort-GUI.moc
g++ -std=c++17 -fPIC -O2 $(pkg-config --cflags Qt6Quick) Sort-GUI.cpp \
    $(pkg-config --libs Qt6Quick) -o Sort-GUI
```
