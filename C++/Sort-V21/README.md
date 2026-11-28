# Sort V21 - C++17 edition

V21 adds `--scan=FSFormat`: whole-drive filesystem-partition scanning with
per-partition signature recovery. It reuses the V20 signature engine
(237 magic formats) inside every partition it finds.

| | |
|---|---|
| **Version** | V21 |
| **Language** | C++ (C++17 edition) |
| **Era** | - |
| **Source** | - |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

## Build / run

`g++ -std=c++17 -O2 -pthread -o Sort-VV21 Sort-VV21.cpp`
Qt6 GUI edition: `moc Sort-GUI.cpp -o Sort-GUI.moc; g++ -std=c++17 -fPIC -O2 $(pkg-config --cflags Qt6Quick) Sort-GUI.cpp Sort-GUI.moc $(pkg-config --libs Qt6Quick) -o Sort-GUI`

## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
