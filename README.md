# Sort - unified repository

One repository, one branch, one directory per version, four languages + a Qt6 GUI.

## Root - the latest version (V19)

| File | What |
|---|---|
| `Sort.sh` | latest Bash edition (V19, self-contained, threaded) |
| `Sort.pas` | latest FreePascal edition (V19 port) |
| `Sort.py` | latest Python edition (V19 era-gated, with --magic standalone engine, stdlib only) |
| `Sort.cpp` | latest C++17 edition (V19 port: single file, no dependencies, native magic/dims/hashes/EXIF/ID3) |
| `Sort-GUI.cpp` | V19 Qt6/QML GUI edition (same engine, all options in the window; see versions/Sort-V19/README.md) |

## versions/ - every version, in order

Each era lives in `versions/Sort-V<version>/` and always contains the same
files (from V19 on: four languages + the Qt6 GUI + README):

* `Sort-V<version>.sh`   - the Bash edition of that era
* `Sort-V<version>.pas`  - its FreePascal translation
* `Sort-V<version>.py`   - its standalone Python edition
* `Sort-V<version>.cpp`  - its standalone C++17 edition (from V18)
* `Sort-GUI.cpp`         - its Qt6/QML GUI edition (from V19)
* `README.md`            - what that version is and does

Lineage: V1.0 - V19 (see `other/Sort-Versions.md` for the full
chronology and era table).

### The Python editions

Every `Sort-V#.##.py` is / fully **independent**: pure Python standard
library, no external commands (`file`, `ffprobe`, `identify`, `exiftool`...)
and no imports of other project files. Run it anywhere with just `python3`.
Each one is gated to its era's own modes, options and keywords, and prints
its exact scope with `-h`. Where the Bash era needed an external tool with
no native equivalent, that option is **stripped** (documented in the
version's README). `/python3 Sort-V17.3.py --self-test/` verifies any of
them in seconds.

## other/ - everything that is not a version

* `Sort.cpp` - the C++20 interactive organizer
* `functions/` - the Bash function toolkit (used by the V16.x lineage)
* `FUNCTIONS/` - the earliest legacy helper library
* `Legacy/` - the archived 4Pulcher-CSort branch (v2.0 "with colors" era)
* `python/` - the Python development tree (engine + per-line packages)
* `Metadata-driven/`, `Media-Intelligent/` - the two separate mini-lineages
* `Sort-Flow.md`, `Sort-Versions.md`, `VERSIONS.txt` - maps and docs

## Quick start

```
./Sort.sh --help                      # latest (Bash)
./Sort.sh --magic Downloads/*          # magic-number detection report
python3 Sort.py --mode=dummy Downloads
g++ -std=c++17 -O2 -pthread -o Sort Sort.cpp   # build the C++ edition
./Sort --version && ./Sort --self-test
python3 versions/Sort-V9.3/Sort-V9.3.py -h     # any historical era
```
