# Sort V19 - Python edition

V19 adds the fifth member of the family: a single-file **Qt6/QML graphical
front-end** (`Sort-GUI.cpp`), wrapping the pure C++17 engine. Every option
of the CLI editions is exposed in the window; the engine itself is
unchanged (V18 heritage: full 237-signature `--magic`, template language,
native hashing/EXIF/ID3).

| | |
|---|---|
| **Version** | V19 |
| **Language** | Python (Python edition) |
| **Era** | - |
| **Source** | - |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

## Build / run

`python3 Sort-V19.py (pure stdlib; --self-test verifies the engine)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
