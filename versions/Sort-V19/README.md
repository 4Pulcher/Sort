# Sort-V19 - the GUI edition arrives (quintet)

V19 adds the fifth member of the family: a single-file **Qt6/QML graphical
front-end** (`Sort-GUI.cpp`), wrapping the pure C++17 engine. Every option
of the CLI editions is exposed in the window; the engine itself is
unchanged (V18 heritage: full 237-signature `--magic`, template language,
native hashing/EXIF/ID3).

## The five files

| File | Edition |
|---|---|
| `Sort-V19.sh` | Bash edition (self-contained, threaded) |
| `Sort-V19.pas` | FreePascal translation (`fpc -Mobjfpc -Sh Sort-V19.pas`) |
| `Sort-V19.py` | Python edition, stdlib only, era-gated |
| `Sort-V19.cpp` | C++17 CLI edition, no dependencies |
| `Sort-GUI.cpp` | C++17 + Qt6/QML GUI edition (same engine, graphical front-end) |

## What is new in V19

* `Sort-GUI.cpp` - one source file containing:
  * the complete V19 C++ engine (identical to `Sort-V19.cpp`)
  * a Qt6 bridge (`SortBridge` QObject) exposing **all** options:
    Sources (multiple files and folders), Target, Mode (dummy/copy/move/
    remove/trash/shred, dummy = the default dry run), `--dirs`,
    `--subdirs`, `--rename`, `--extension`, `--type`, Recursive, Hidden,
    Follow links, Replace, Pause, Jobs, `--log` (+ Undo log button),
    Cleanup empty dirs, Language (en/nl/fr/de/tr), Colors, Icons
  * an embedded QML document (no separate .qml files): source list with
    file/folder pickers, Preview (dry run) and RUN buttons, streamed log
    panel, Self-test and Undo buttons
  * the UI lines of the Organizer are streamed live from the worker
    thread into the GUI log; `--cli` on the command line drops into the
    embedded CLI engine instead of opening the window
  * GUI note: the console "ask" collision prompt cannot be answered from
    a window, so in the GUI it maps to skip (use always/never instead)

* Version bump: Bash, FreePascal, Python and C++ CLI editions are
  re-badged from 18 to 19 with no functional change.

## Build and run (Debian)

```
sudo apt install build-essential qt6-base-dev qt6-declarative-dev
moc Sort-GUI.cpp -o Sort-GUI.moc
g++ -std=c++17 -fPIC -O2 $(pkg-config --cflags Qt6Quick) Sort-GUI.cpp \
    $(pkg-config --libs Qt6Quick) -o Sort-GUI
./Sort-GUI                # opens the window
./Sort-GUI --cli --help   # embedded CLI engine
```

CMake alternative: `find_package(Qt6 COMPONENTS Quick REQUIRED)`,
`qt_add_executable(Sort-GUI Sort-GUI.cpp)` with `CMAKE_AUTOMOC ON`.

## Safety

As everywhere in the lineage: the GUI defaults to `dummy` (dry run);
nothing moves until you switch the Mode and press RUN.
