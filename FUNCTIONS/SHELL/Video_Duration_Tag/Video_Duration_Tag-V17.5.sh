Video_Duration_Tag() {
	local Seconds

	Seconds=$(Get_Duration "$1") || return 1
	Duration_Tag_From_Seconds "$Seconds"
}
