# functions/imagemagick

> Complete image toolkit - ImageMagick identify / magick

A complete, standalone bag of image tools built on ImageMagick: dimension, format, color, depth, quality, DPI, orientation, camera and GPS getters, plus resize / thumbnail / convert / rotate / grayscale / strip actions. Every function prints its result on stdout and returns non-zero on failure (127 when ImageMagick is missing).

When the deps module is loaded, a missing ImageMagick triggers an install proposal (see ../deps).

## Functions

### Dimensions

- `Get_Image_WxH`
- `Get_Image_Width`
- `Get_Image_Height`

### Format and properties

- `Get_Image_Format`
- `Get_Image_Colors`
- `Get_Image_Depth`
- `Get_Image_Quality`
- `Get_Image_DPI`
- `Get_Image_Orientation`

### Metadata

- `Get_Image_Camera`
- `Get_Image_GPS`
- `Get_Image_Meta`
- `Image_Is_Valid`

### Classification

- `Get_WxH_Format`

### Actions

- `Image_Resize`
- `Image_Thumbnail`
- `Image_Convert`
- `Image_Rotate`
- `Image_Grayscale`
- `Image_Strip`

Total: 20 functions.