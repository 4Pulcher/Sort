# functions/ffmpeg

> Complete media toolkit - ffmpeg / ffprobe

A complete, standalone bag of media tools built on ffmpeg/ffprobe: codecs, container, duration, bitrate, FPS, channels, sample rate, tag getters, validity checks, plus extract-audio / convert / thumbnail / strip actions. Every function prints its result on stdout and returns non-zero on failure (127 when ffmpeg/ffprobe is missing).

## Functions

### Dimensions

- `Get_Media_WxH`

### Streams and container

- `Get_Video_Codec`
- `Get_Audio_Codec`
- `Get_Container`
- `Get_Duration`
- `Get_Duration_Human`
- `Get_Bitrate`
- `Get_FPS`
- `Get_Audio_Channels`
- `Get_Sample_Rate`

### Tags

- `Get_Media_Title`
- `Get_Media_Artist`
- `Get_Media_Album`
- `Get_Media_Genre`
- `Get_Media_Track`
- `Get_Media_Date`
- `Get_Media_Tags`

### Validity

- `Media_Is_Valid`

### Composite tag lines

- `Get_Audio_Info`
- `Get_Video_Title`

### Actions

- `Media_Extract_Audio`
- `Media_Convert`
- `Media_Thumbnail`
- `Media_Strip_Metadata`

Total: 24 functions.