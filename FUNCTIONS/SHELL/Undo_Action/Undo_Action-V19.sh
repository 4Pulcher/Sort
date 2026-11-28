Undo_Action() {
	[ -n "$UndoFile" ] || return 0
	printf '%s\n' "$*" >>"$UndoFile"
}
