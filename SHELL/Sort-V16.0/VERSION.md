# VERSION.md - Sort V16.0 (SHELL)

## About

Complete rewrite of the Sort mainline as a driver over the `functions/` library
at the repository root: it collects every file to treat into an array up front,
classifies each file by MIME type / size, and processes the array through a
bounded pool of background jobs (threading). Verbose by default, colored
output via `--colored`, dry-run preview by default.

| Version | Language | Era | Source |
|---|---|---|---|
| V16.0 | SHELL | V16.x — `functions/` library rewrite | Rewrite commit `a071fdd` |

## Changes

- First version built on the modular `functions/` toolkit (deps, colors, file,
- Introduced `--jobs=N` threading, status tags (COPIED/MOVED/PREVIEW/SKIPPED/FAILED)
- This copy loads the library from `../../functions/` so it runs from its

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
