Same_Hash() {
	local A=$1
	local B=$2
	local Algo=${3:-sha256}
	local HashA HashB

	HashA=$(Get_Hash "$Algo" "$A") || return 1
	HashB=$(Get_Hash "$Algo" "$B") || return 1
	[[ "$HashA" == "$HashB" ]]
}
