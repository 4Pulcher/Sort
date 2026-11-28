Magic_Report_All() {
	local F
	for F in "${Targets[@]}"; do
		Magic_Report "$F"
	done
	return 0
}
