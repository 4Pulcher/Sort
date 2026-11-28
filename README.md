# Sort - Media-Intelligent File Organizer

One repository, four languages, 105 versions. **Sort** organizes
files by their real content (magic bytes, dimensions, hashes, EXIF/ID3 tags),
not just by name - and from V20/V21 it also recovers data: raw device scans,
partition discovery and file carving.

| Directory | Language | What |
|---|---|---|
| `SHELL/` | Bash | every `Sort-V#.#.sh` edition, one directory per version |
| `FreePascal/` | FreePascal | every `Sort-V#.#.pas` port |
| `Python/` | Python 3 | every standalone `Sort-V#.#.py` edition (stdlib only) |
| `C++/` | C++17 + Qt6 | every `Sort-V#.#.cpp` edition and the Qt6 `Sort-GUI.cpp` files |
| `FUNCTIONS/` | all | every function used in the versions, one file per function per version (`FUNCTIONS/$LANG/<Name>/<Name>-V#.#`) |
| `VARIA/` | all | non-lineage material: legacy branches, prototype mini-lineages, dev trees, docs |

Latest version: **V22** (in `SHELL/Sort-V22`, `FreePascal/Sort-V22`,
`Python/Sort-V22`, `C++/Sort-V22`). The lineage runs V1.0 to V22; see
[VERSION.md](VERSION.md) for the era table and
[VARIA/Docs/Sort-Versions.md](VARIA/Docs/Sort-Versions.md) for the full
chronology.

## Download

- Repository: <https://github.com/4Pulcher/Sort>
- Zip of the latest state: <https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip>
- Single file, plain: `https://raw.githubusercontent.com/4Pulcher/Sort/main/SHELL/Sort-V22/Sort-V22.sh`

## Caution - test phase

**Be careful with these scripts.** The Sort code is in a **test phase**: every
version passes syntax checks (`bash -n`, `--self-test` where available), but it
is not field-tested on real data. Always try a version on a scratch copy of a
few files first, and read the dry-run preview before confirming any action.
Destructive modes (`--mode=remove`, `shred`, ...) exist: keep backups.

## About the author

Sort is written by **Ali ISIN (HEjder / Ejder)**, writing under the nickname **Ejder / HEjder**.
Every script is a HEjder edition: syntax errors corrected, formatting unified,
every function commented, and the Bash editions end with
`Thanks for using HEjder scripts!`.

## Languages and versions

- **Bash (SHELL/)**: 105 versions, V1.0 to V22 - the reference lineage.
- **FreePascal (FreePascal/)**: a port of every version, FreePascal 3.2.2 (`-Mobjfpc -Sh`).
- **Python (Python/)**: standalone editions from the V17.x era onward - era-gated, pure standard library, `--self-test`.
- **C++17 (C++/)**: single-file ports from V18 onward, plus the Qt6/QML GUI editions from V19 onward.

Build examples: `bash SHELL/Sort-V22/Sort-V22.sh --help`,
`python3 Python/Sort-V22/Sort-V22.py --self-test`,
`g++ -std=c++17 -O2 -pthread -o Sort C++/Sort-V22/Sort-V22.cpp`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's four-language family - and to Garry's
magic-number collection, which feeds the V22 signature engine.

*Thanks for using HEjder scripts!*
