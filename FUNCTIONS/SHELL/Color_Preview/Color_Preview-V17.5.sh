Color_Preview() {
	local Name
	for Name in red green yellow blue magenta cyan white gray bold dim underline; do
		Print_Color "$Name" "$Name"
	done
	return 0
}
