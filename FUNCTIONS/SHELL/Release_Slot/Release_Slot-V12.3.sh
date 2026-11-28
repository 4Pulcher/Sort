Release_Slot() {
	local Slot=$1
	rmdir "$SLOT_DIR/slot_$Slot" 2>/dev/null
}
