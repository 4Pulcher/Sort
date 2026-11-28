Build_Segments() {
	local Spec=$1 File=$2 Mime=$3 Main=$4
	local Key Seg Out='' Rc

	Spec=${Spec//+/,}
	IFS=',' read -ra Keys <<<"$Spec"

	for Key in "${Keys[@]}"; do
		Key=${Key// /}
		[ -n "$Key" ] || continue

		Seg=$(Resolve_Segment "$Key" "$File" "$Mime" "$Main")
		Rc=$?
		[ "$Rc" -eq 2 ] && Seg=$Key
		[ "$Rc" -le 1 ] && [ -n "$Seg" ] && Out="$Out/$Seg"
	done

	printf '%s' "${Out#/}"
}
