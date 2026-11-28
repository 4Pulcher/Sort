Fs_Probe_Hex() {
	local H=$1
	Fs_Tok=''
	[ "${H:0:12}"    = '4c554b53babe'     ] && { Fs_Tok=luks;     return 0; }
	[ "${H:6:16}"    = '4e54465320202020' ] && { Fs_Tok=ntfs;    return 0; }
	[ "${H:6:12}"    = '455846415420'     ] && { Fs_Tok=exfat;   return 0; }
	[ "${H:108:10}"  = '4641543136'       ] && { Fs_Tok=fat16;   return 0; }
	[ "${H:108:10}"  = '4641543132'       ] && { Fs_Tok=fat12;   return 0; }
	[ "${H:164:10}"  = '4641543332'       ] && { Fs_Tok=fat32;   return 0; }
	[ "${H:128:16}"  = '5f42485266535f4d' ] && { Fs_Tok=btrfs;   return 0; }
	[ "${H:0:8}"     = '58465342'         ] && { Fs_Tok=xfs;     return 0; }
	[ "${H:104:12}"  = '526549734572'     ] && { Fs_Tok=reiserfs; return 0; }
	[ "${H:2048:4}"  = '482b'             ] && { Fs_Tok=hfs;     return 0; }
	[ "${H:2048:4}"  = '4858'             ] && { Fs_Tok=hfs;     return 0; }
	[ "${H:2160:4}"  = '53ef'             ] && { Fs_Tok=ext;     return 0; }
	[ "${H:2104:20}" = '53574150535041434532' ] && { Fs_Tok=swap; return 0; }
	return 1
}
