# functions/hash

> Complete checksum toolkit - md5 / SHA family / crc32 / blake2

A complete, standalone bag of checksum tools: the md5/SHA family, crc32, blake2, a generic dispatcher, string hashing, verification, comparison, containment, directory diff/minus and duplicate finding. Every function prints its result on stdout and returns non-zero on failure (127 when the needed tool is missing).

## Functions

### Per-algorithm getters

- `Get_MD5Sum`
- `Get_SHA1Sum`
- `Get_SHA224Sum`
- `Get_SHA256Sum`
- `Get_SHA384Sum`
- `Get_SHA512Sum`
- `Get_B2Sum`
- `Get_CRC32`

### Dispatcher and strings

- `Get_Hash`
- `Get_Hash_Of_String`

### Verification

- `Verify_Hash`
- `Files_Are_Identical`
- `Same_Hash`
- `Files_Differ`

### Containment (A in B)

- `File_Contains` — is the content of file A inside file B (binary-safe; swap arguments for the reverse)
- `Find_Copy_In` — find files inside a directory that are identical to a file

### Directory comparison

- `Dir_Diff` — full tree comparison: `SAME` / `DIFFERENT` / `ONLY_IN_A` / `ONLY_IN_B`
- `Dir_Minus` — A minus B by path (files in A with no counterpart path in B)
- `Dir_Minus_Content` — A minus B by content (files in A whose content exists nowhere in B)
- `Dir_Same` — predicate: are two directory trees content-identical?

### Screening

- `Get_Quick_Hash`
- `Find_Duplicates`

Total: 22 functions.
