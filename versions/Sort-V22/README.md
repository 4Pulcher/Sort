# Sort V22 - the expanded-signature edition

V22 grows the embedded signature table from 237 to **260 formats**. The new
signatures were mined from Garry's magic-number CSV, keeping only the columns
that matter for detection (header hex, header offset, extension) and only the
genuinely useful entries.

## What is new in V22

23 new signatures across all five editions (Bash, Python, FreePascal, C++17,
Qt6 GUI), active everywhere the engine runs: `--magic` reports, `--scan-raw`
and `--scan` partition/carve recovery:

* **Disk images**: Apple DMG, Virtual PC VHD (conectix), VMware COWD sparse,
  VMware descriptor text, compressed ISO (CSO), EnCase E01 evidence files
* **Photos/graphics**: Canon CRW raw, Paint Shop Pro, Better Portable Graphics
  (BPG), Windows metafile (WMF), binary EPS
* **Forensics**: Windows event logs (EVT/EVTX), Outlook Express DBX mail
  stores, Skype user database (DBB)
* **Personal data**: vCard contacts (VCF), OneNote notebooks, InDesign
  documents, TrueType (Mac `true\0`), Digital Speech Standard (DSS),
  DVD IFO navigation files
* **Crypto**: MultiBit Bitcoin wallets (`\norg.bitcoin.pro`), 1Password cloud
  keychains (OPVAULT)

Rejected from the CSV on purpose: ~370 junk or high-false-positive rows
(AOL-era formats, BIOS/RAM dumps, all-zero or 2-byte headers, `(none)`
extensions, formats already covered by existing or wildcard signatures
(e.g. all `ftyp` MP4/M4A/HEIC variants, RIFF/WEBP/AVI/WAV, PCX, AIFF/AIFC)).

Everything else is unchanged from V21: the `--scan=FSFormat` partition scan
(MBR/GPT + lost-partition probe, per-partition signature recovery, broken
marking, FS-CARVE copy mode, JSONL + undo, GUI fragment tree with save).

## Editions

| File | Notes |
|---|---|
| `Sort-V22.sh` | Bash edition, self-contained. Slow on big drives; prefer C++ for real disks. |
| `Sort-V22.py` | Python edition, stdlib only, `--self-test` 23/23. |
| `Sort-V22.pas` | FreePascal edition: `fpc -Mobjfpc -Sh Sort-V22.pas` |
| `Sort-V22.cpp` | C++17 edition: `g++ -std=c++17 -O2 -pthread -o Sort Sort-V22.cpp` |
| `Sort-GUI.cpp` | Qt6/QML edition, same engine + FS tree GUI. Build: `moc Sort-GUI.cpp -o Sort-GUI.moc; g++ -std=c++17 -fPIC -O2 $(pkg-config --cflags Qt6Quick) Sort-GUI.cpp Sort-GUI.moc $(pkg-config --libs Qt6Quick) -o Sort-GUI` |

Python and Bash were validated byte-for-byte against each other: the 12-file
magic fixture (all 12 new formats detected identically, MATCH verdicts) and a
4 MiB raw image whose embedded DMG/CRW/wallet/DBX fragments produced
identical `--scan-raw` hit lists.
