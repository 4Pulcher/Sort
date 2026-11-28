# Sort V16.0 - Python edition

Complete rewrite of the Sort mainline as a driver over the `functions/` library
at the repository root: it collects every file to treat into an array up front,
classifies each file by MIME type / size, and processes the array through a
bounded pool of background jobs (threading). Verbose by default, colored
output via `--colored`, dry-run preview by default.

| | |
|---|---|
| **Version** | V16.0 |
| **Language** | Python (Python edition) |
| **Era** | V16.x — `functions/` library rewrite |
| **Source** | Rewrite commit `a071fdd` |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

## Build / run

`python3 Sort-V16.0.py (pure stdlib; --self-test verifies the engine)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
