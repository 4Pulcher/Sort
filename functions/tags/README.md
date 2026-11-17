# functions/tags

> Audio-tag toolkit - ID3v1 / ID3v2, pure bash

A complete, standalone bag of audio-tag tools that reads ID3v1 and ID3v2 tags
from MP3 and other tagged audio files without any external tag tool: raw
field access by friendly name, per-version probing, the 126-entry genre
table, and conventional `Artist/Year - Album` directory naming. Every getter
prints its result on stdout and returns non-zero when the field is missing.

When the EXIF module is loaded, the friendly getters fall back to
`Exif_Field` (exiftool) for formats ID3 cannot cover (FLAC, Ogg, M4A, WMA).
When the deps module is loaded, a missing `iconv` triggers an install
proposal (see ../deps).

## Functions

### ID3v1 (last 128 bytes, "TAG" magic)

- `Id3v1_Present <file>` \u2014 predicate: a valid ID3v1 trailer?
- `Id3v1_Field <file> <field>` \u2014 raw fixed-offset field: title, artist,
  album, year, comment, track (only when the v1.1 zero-byte marker is set),
  genre (index number)
- `Id3v1_Genre_Name <index>` \u2014 126-entry genre table (80 standard genres
  + Winamp extensions 80\u2013125)

### ID3v2 (header + frame walk)

- `Id3v2_Present <file>` \u2014 predicate: an "ID3" header?
- `Id3v2_Major <file>` \u2014 version major (2, 3 or 4)
- `Id3v2_Tag_Size <file>` \u2014 synchsafe tag size in bytes
- `Id3v2_Field <file> <frame>` \u2014 text of one frame ID; supports v2.2
  (3-char IDs, 3-byte sizes), v2.3 (4-char IDs, 4-byte sizes) and v2.4
  (synchsafe sizes); decodes ISO-8859-1, UTF-16 (BOM), UTF-16BE and UTF-8
  payload encodings via `iconv`

### Generic access

- `Id3_Field <file> <name>` \u2014 friendly name to best available value: tries
  the ID3v2 candidate frames first (title\u2192TIT2/TT2, artist\u2192TPE1/TP1,
  album\u2192TALB/TAL, year\u2192TDRC/TYER/TYE, genre\u2192TCON/TCO,
  track\u2192TRCK/TRK), then ID3v1, then resolves numeric genres
  ("(17)" or "17" \u2192 Rock); returns 2 for an unknown field name

### Friendly getters (with EXIF fallback)

- `Get_Audio_Title <file>`
- `Get_Audio_Artist <file>`
- `Get_Audio_Album <file>`
- `Get_Audio_Year <file>`
- `Get_Audio_Genre <file>`
- `Get_Audio_Track <file>`

### Naming

- `Get_Audio_Tags_Dir <file>` \u2014 conventional tree path `Artist/Year - Album`
  (missing parts are skipped; everything sanitized for directory use)

## Usage

```bash
source tags.sh

Id3_Field song.mp3 title          # -> My Song
Get_Audio_Genre song.mp3          # -> Rock
Get_Audio_Tags_Dir song.mp3       # -> HEjder/1999 - Big_Album
```

Example: sort a music collection into `Artist/Year - Album/Track`:

```bash
./Sort.sh --mode=move --dirs=id3 --rename=id3-track ~/Music
```

Total: 15 functions.
