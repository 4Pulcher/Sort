# VERSION.md - Sort V19 (Python)

## About

V19 adds the fifth member of the family: a single-file **Qt6/QML graphical
front-end** (`Sort-GUI.cpp`), wrapping the pure C++17 engine. Every option
of the CLI editions is exposed in the window; the engine itself is
unchanged (V18 heritage: full 237-signature `--magic`, template language,
native hashing/EXIF/ID3).

| Version | Language | Era | Source |
|---|---|---|---|
| V19 | Python | - | - |

## Changes

- `Sort-GUI.cpp` - one source file containing:
- the complete V19 C++ engine (identical to `Sort-V19.cpp`)
- a Qt6 bridge (`SortBridge` QObject) exposing **all** options:
- an embedded QML document (no separate .qml files): source list with
- the UI lines of the Organizer are streamed live from the worker
- GUI note: the console "ask" collision prompt cannot be answered from
- Version bump: Bash, FreePascal, Python and C++ CLI editions are

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
