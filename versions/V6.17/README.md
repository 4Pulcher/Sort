# Sort — Version 6.17

> Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

| | |
|---|---|
| **Version** | 6.17 |
| **Era** | V15.x — Modular library era |
| **Source** | `uWP78Sbs` |
| **Size** | Mangled `else echo "$( … )" &` subshell construct lines |
| **Preceded by** | V6.16 |
| **Followed by** | V6.18 |

## About this version

Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

## Notes

- Rebuilt as `else ( … ) &` with the missing inner `fi` restored

## Fixes applied (HEjder edition)

A mangled `else echo "$( ... )"` background construct was rebuilt as a proper `else ( ... ) &` subshell, restoring the missing inner `fi`.

## Usage

```bash
chmod +x Sort-V6.17.sh
./Sort-V6.17.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.
