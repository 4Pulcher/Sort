Get_Name_MIME() {
	local Name=${1##*/}
	local Ext=${Name##*.}

	[ -n "$Name" ] || return 1
	[[ "$Name" == *.* && "$Name" != .* || "$Name" == *.*.* ]] || return 1

	Get_Extension_MIME "$Ext"
}
