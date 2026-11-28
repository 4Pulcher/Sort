Strip_Target() {
	local Target=$1 Tmp

	Tmp="$Target.strip.$$"

	if EXIF_Strip "$Target" "$Tmp"; then
		mv -f -- "$Tmp" "$Target"
		[ "$Quiet" -eq 1 ] || Print_Info "Stripped metadata: $Target"
	else
		rm -f -- "$Tmp"
		Print_Warning "Could not strip metadata: $Target"
	fi
}
