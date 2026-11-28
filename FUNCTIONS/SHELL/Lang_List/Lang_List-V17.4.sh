Lang_List() {
	local Code
	printf '%s\n' "$(T 'Available languages (--lang=XX):')"
	for Code in $LANG_CODES; do
		printf '  %s — %s\n' "$Code" "$(Lang_Name "$Code")"
	done
}
