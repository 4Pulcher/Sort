# VERSION.md - Sort V22 (C++)

## About

V22 grows the embedded signature table from 237 to **260 formats**. The new
signatures were mined from Garry's magic-number CSV, keeping only the columns
that matter for detection (header hex, header offset, extension) and only the
genuinely useful entries.

| Version | Language | Era | Source |
|---|---|---|---|
| V22 | C++ | - | - |

## Changes

- Disk images**: Apple DMG, Virtual PC VHD (conectix), VMware COWD sparse,
- Photos/graphics**: Canon CRW raw, Paint Shop Pro, Better Portable Graphics
- Forensics**: Windows event logs (EVT/EVTX), Outlook Express DBX mail
- Personal data**: vCard contacts (VCF), OneNote notebooks, InDesign
- Crypto**: MultiBit Bitcoin wallets (`\norg.bitcoin.pro`), 1Password cloud

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!

## Audit corrections (V22.1)

This edition is the corrected V22 baseline from the external code audit:
- Cross-language semantics unified: `--mode=remove`, `trash` and `shred` act on
  the calculated TARGET path in every language (the Bash reference behaviour);
  a missing target is reported as a failure.
- Python: single-pass multi-algorithm hashing, stat reuse, lock-protected
  shared counters.
- C++: `fs::file_size` error-code handling, `std::queue` construction,
  greedy hex-escape signature literals (`\xfd7zXZ`, `\x7fELF`, `\x1aE\xdf\xa3`)
  split into safe adjacent literals, remove-counter failure check.
- FreePascal: header version corrected to 22, inert `--compare` option removed.
- README.md: build commands corrected, Qt6 GUI instructions kept in the C++
  directory only.
