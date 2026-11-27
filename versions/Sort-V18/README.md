# Sort-V18 - the C++ edition arrives (quartet)

V18 adds the fourth language to the family: a single-file, dependency-free
**C++17** edition (`Sort-V18.cpp`), alongside the usual Bash, FreePascal
and Python trio. All four editions now implement the same feature union,
including the full 237-signature `--magic` detection table inherited from
V17.5.

## The four files

| File | Edition |
|---|---|
| `Sort-V18.sh` | Bash edition (self-contained, threaded, 237-signature `--magic`) |
| `Sort-V18.pas` | FreePascal translation (`fpc -Mobjfpc -Sh Sort-V18.pas`) |
| `Sort-V18.py` | Python edition, stdlib only, era-gated (`python3 Sort-V18.py -h`) |
| `Sort-V18.cpp` | C++17 edition, no dependencies, no external commands |

## What is new in V18

* `Sort-V18.cpp` - a pure C++17 port of `Sort-V18.py`:
  * one file, standard library only: no `file`, no ImageMagick, no FFmpeg,
    no ExifTool, no OpenSSL, no Qt, no Boost, no CMake
  * native MIME sniffing, image dimensions (PNG/GIF/BMP/WEBP/JPEG),
    native MD5 and SHA-1/224/256/384/512 hashing, JPEG EXIF and MP3
    ID3v1/ID3v2 parsing, V17 template language (lower:/upper:/raw:
    prefixes and a|b|c fallbacks)
  * all six modes: dummy (default dry run), copy, move, remove, trash
    (freedesktop), shred (3 random passes + fsync)
  * `--jobs` thread pool, JSONL `--log` and `--undo`, `--type` filters,
    collision handling (`--replace ask|always|never`), the same 5 UI
    languages (en/nl/fr/de/tr) with colors and icons
  * the identical 237-signature `--magic` report (byte-for-byte the same
    4-line blocks as the sh/py/pas editions)
  * era gate matching the Python edition: same allowed modes, flags and
    keywords, same `-h` usage text
  * `--self-test` with the same 23 checks as `Sort-V18.py`

* Version bump: the Bash, FreePascal and Python editions are re-badged
  from 17.5 to 18 with no functional change (V17.5 heritage: the full
  237-signature `--magic` table).

## Build and run

```
g++ -std=c++17 -O2 -pthread -o Sort Sort-V18.cpp
./Sort --version
./Sort --self-test          # 23 checks
./Sort --magic FILE...       # magic-number detection report
./Sort --mode=dummy --dirs=mime-main Downloads
```

Any C++17 compiler works (g++ 8+, clang++ 7+). Needs nothing but libstdc++
and a POSIX userland.

## Validation

The magic table in the C++ edition is generated from the same source of
truth as the Python edition (same 237 entries, same first-match order).
The hash implementations were verified against Python's `hashlib` on a
byte level during the port, and `--self-test` exercises MIME sniffing,
dimensions, hashes, templates, a threaded copy run and undo.
