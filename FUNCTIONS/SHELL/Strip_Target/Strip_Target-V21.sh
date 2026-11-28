Strip_Target() {
	local Target=$1 Tmp

	Tmp="$Target.strip.$$"

	if EXIF_Strip "$Target" "$Tmp"; then
		mv -f -- "$Tmp" "$Target"
		[ "$Quiet" -eq 1 ] || Print_Info "$(Tf 'Stripped metadata: %s' "$Target")"
	else
		rm -f -- "$Tmp"
		Print_Warning "$(Tf 'Could not strip metadata: %s' "$Target")"
	fi
}
