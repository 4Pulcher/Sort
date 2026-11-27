# Sort V21 - the `--scan` edition

V21 adds `--scan=FSFormat`: whole-drive filesystem-partition scanning with
per-partition signature recovery. It reuses the V20 signature engine
(237 magic formats) inside every partition it finds.

## What is new in V21

`--scan=FORMATS` (or bare `--scan`), with the device or image path as the
positional argument:

```
sudo ./Sort.sh --scan=all /dev/sdb                 # report everything
sudo ./Sort.sh --scan=ntfs,fat32 /dev/sdb --mode=copy --target=/rescue
python3 Sort.py --scan=all disk.img
```

* **Phase 1 - partitions**: parses the MBR and GPT partition tables, then
  probes 512-byte-aligned offsets for filesystem signatures to also find
  **lost/deleted partitions** (ntfs, exfat, fat12/16/32, ext, btrfs, xfs,
  reiserfs, hfs, swap, luks). Lost partitions get an estimated `~size`.
  Listed partitions are numbered first, then lost ones.
* **Phase 2 - recovery**: runs the V20 signature engine inside each
  selected partition. Fragments that cross their partition end or overlap
  another partition are marked `broken` (overwritten data).
* **Formats**: `all,ntfs,exfat,fat12,fat16,fat32,ext,btrfs,xfs,reiserfs,hfs,swap,luks`
  (comma-separated); unknown formats are refused with rc 64.
* **Output**: `dummy` (default) prints a report; `copy` carves fragments to
  `Target/FS-CARVE/p<N>-<start>/<offset>.<ext>` and logs JSONL
  (`{"action":"carved","src":"dev@off","dst":...,"part":N[,"broken":true]}`).
  `--undo` deletes carved fragments (carved data never goes back).
* **Out of space**: on ENOSPC during copy you are prompted for a new target
  directory (empty answer aborts, rc 65).
* **GUI (Sort-GUI.cpp)**: a new FS section with device + format fields, a
  partition-grouped fragment tree with checkboxes, Select all, and a
  "Save ticked fragments..." button with a folder picker. This release also
  fixes a V20 GUI bug (the scanRaw field was not a Q_PROPERTY, so the raw
  scan device never reached the engine).

## Safety

* The scan itself is read-only; `--mode` gates carving.
* `move`, `remove`, `trash` and `shred` are refused with
  `SCAN: --scan supports dummy and copy only (mode 'X' refused)`, rc 64.
* A missing device or an undeterminable size also fail loudly (rc 64 / 66).

## Editions

| File | Notes |
|---|---|
| `Sort-V21.sh` | Bash edition, self-contained. Works, but slow on big drives; prefer the C++ edition for real disks. |
| `Sort-V21.py` | Python edition, stdlib only, `--self-test` 23/23. |
| `Sort-V21.pas` | FreePascal edition: `fpc -Mobjfpc -Sh Sort-V21.pas` |
| `Sort-V21.cpp` | C++17 edition: `g++ -std=c++17 -O2 -pthread -o Sort Sort-V21.cpp` |
| `Sort-GUI.cpp` | Qt6/QML edition, same engine + FS tree GUI. Build: `moc Sort-GUI.cpp -o Sort-GUI.moc; g++ -std=c++17 -fPIC -O2 $(pkg-config --cflags Qt6Quick) Sort-GUI.cpp Sort-GUI.moc $(pkg-config --libs Qt6Quick) -o Sort-GUI` |

Python and Bash were validated byte-for-byte against each other on MBR and
GPT fixtures (listed + lost partitions, exact/capped/broken fragments, copy,
JSONL, undo, refusals). C++/Pascal/Qt compile on Debian and follow the same
specification.
