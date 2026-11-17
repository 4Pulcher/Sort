# functions/exif

> Complete EXIF toolkit - exiftool / ImageMagick fallback

A complete, standalone bag of EXIF tools built on exiftool (with an ImageMagick identify fallback for common tags): generic tag access, full dumps, camera / lens / exposure / GPS getters, plus strip / set / copy actions. Every function prints its result on stdout and returns non-zero on failure (127 when no EXIF reader is installed).

When the deps module is loaded, a missing exiftool triggers an install proposal (see ../deps).

## Functions

### Generic access and dumps

- `Get_EXIF` — read any EXIF tag by its exiftool name (e.g. `DateTimeOriginal`, `ISO`)
- `Get_EXIF_All` — every tag as `Tag: Value`, one per line
- `Get_EXIF_Tags` — tag names only
- `EXIF_Is_Present` — predicate: any EXIF metadata at all?

### Date and camera

- `Get_EXIF_Date` — DateTimeOriginal
- `Get_EXIF_CreateDate` — CreateDate
- `Get_EXIF_Camera` — Make + Model
- `Get_EXIF_Lens` — LensModel (fallback LensMake)

### Exposure

- `Get_EXIF_ISO`
- `Get_EXIF_Exposure`
- `Get_EXIF_Aperture`
- `Get_EXIF_FocalLength`
- `Get_EXIF_Flash`
- `Get_EXIF_Orientation`

### GPS

- `Get_EXIF_GPS_Lat` — decimal degrees where the reader supports it
- `Get_EXIF_GPS_Lon`
- `Get_EXIF_GPS` — lat,lon
- `Get_EXIF_GPS_Alt`

### Author and copyright

- `Get_EXIF_Artist`
- `Get_EXIF_Copyright`

### Actions

- `EXIF_Strip <in> <out>` — write a metadata-stripped copy (exiftool, or magick/convert -strip fallback)
- `EXIF_Set <tag> <value> <file>` — set one EXIF tag in place
- `EXIF_Copy <src> <dst>` — copy all EXIF tags from src onto dst in place

Total: 23 functions.
