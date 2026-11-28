_Exif_Has_Reader() {
	command -v exiftool >/dev/null || command -v identify >/dev/null
}
