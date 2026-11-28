#!/bin/bash
# by Ali_ISIN

# Check requirements
declare -A Required=( [file]='Linux Base' [stat]='Linux Base' [cp]='Linux Base' [mv]='Linux Base' [rm]='Linux Base' [find]='Linux Base' [sha256sum]='Linux Base' [ffprobe]='FFMPEG' [identify]='ImageMagick' )
for Key in ${!Required[@]} ; do
	if command -v $Key &> /dev/null ; then
		echo "Ready : $(command -v $Key)"
	else
		echo "Error: \'$Key\' command is not installed or not available on the system."
		echo "==> Consider installing: ${Required[$Key]}"
		exit 10
	fi
done

# Set escape
function Break { IFS=$OIFS ; exit 1; }
trap Break INT

shopt -s dotglob

function Get_SHA256Sum {
	local SUM=$(sha256sum -b "$1" | tr -d '\n')
	printf ${SUM%% *}
}

function Get_MIME {
	local MIME=$(file --mime-type "$1" | tr -d '\n')
	printf ${MIME##* }
}

function Get_File_Name {
	local Name=${1##*/}
	printf ${Name%%.*}
}

function Get_File_Extension {
	local Extension=${1##*/}
	printf ${Extension##*.}
}

function Get_File_Size {
	printf $(stat -c "%s" "$File" | tr -d '\n')
}

function Get_Image_WxH {
	local WxH=$(identify -format "%wx%h-" "$1" | tr -d '\n')
	printf ${WxH%%-*}
}

function Get_Video_WxH {
	printf $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" | tr -d '\n')
}

function Get_File_WxH_Format {
	local W=${1%%x*}
	local H=${1##*x}

	if [ "$W" != "" ] && [ "$H" != "" ] ; then
		if [ "$W" = "0" ] && [ "$H" = "0" ] ; then printf "ZERO" ;
		elif [ "$W" -lt "32" ] && [ "$H" -lt "32" ] ; then printf "TINY" ;
		elif [ "$W" -lt "512" ] && [ "$H" -lt "512" ] ; then printf "SMALLER" ;
		elif [ "$W" -lt "1024" ] && [ "$H" -lt "1024" ] ; then printf "SMALL" ;
		elif [ "$W" -lt "2048" ] && [ "$H" -lt "2048" ] ; then printf "MEDIUM" ;
		elif [ "$W" -lt "4096" ] && [ "$H" -lt "4096" ] ; then printf "BIG" ;
		elif [ "$W" -lt "8192" ] && [ "$H" -lt "8192" ] ; then printf "BIGGER" ;
		elif [ "$W" -lt "16384" ] && [ "$H" -lt "16384" ] ; then printf "SUPER" ;
		else printf "HUGE" ;
		fi ;

		printf "/" ;

		if [ "$W" -gt "$H" ] ; then printf "WIDE" ;
		elif [ "$W" -lt "$H" ] ; then printf "HIGH" ;
		else printf "SQUARE" ;
		fi
	fi
}

function Draw_Line {
	local Width=$(tput cols)
	local Line=${#1}
	while [ $Width -gt $Line ] ; do Width=$(( $Width - $Line )) ; printf "%b" $1 ; done ; printf "\n"
}

declare -a Total
declare -a Counter
declare -a DirName

CLEAR='\033[0J'
RESET='\033[0m'

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGANTA='\033[1;35m'

RED_YELLOW='\033[41;33m'

function Sort {

	((Current++))

	Total[$Current]=$#
	Counter[$Current]=0

	for Item in $@ ; do
		case ${Item,,} in
		"--pause="*)
			((Total[$Current]--))
			Pause=${Item#*=}
			echo "Pause: $Pause"
			;;
		"--probe")
			((Total[$Current]--))
			Probe="yes"
			echo "Probe: $Probe"
			;;
		"--type="*)
			((Total[$Current]--))
			Type=${Item#*=}
			echo "Type: $Type"
			;;
		"--copy")
			((Total[$Current]--))
			Mode="copy"
			echo "Mode: $Mode"
			;;
		"--move")
			((Total[$Current]--))
			Mode="move"
			echo "Mode: $Mode"
			;;
		"--remove")
			((Total[$Current]--))
			Mode="remove"
			echo "Mode: $Mode"
			;;
		"--recursive")
			((Total[$Current]--))
			Recursive="yes"
			echo "Recursive: $Recursive"
			;;
		"--replace")
			((Total[$Current]--))
			Replace="yes"
			echo "Replace: $Replace"
			;;
		"--rename="*)
			((Total[$Current]--))
			Rename=${Item#*=}
			echo "Rename: $Rename"
			;;
		"--extension="*)
			((Total[$Current]--))
			Extension=${Item#*=}
			echo "Extension: $Extension"
			;;
		"--dirs="*)
			((Total[$Current]--))
			Dirs=${Item#*=}
			echo "Directories: $Dirs"
			;;
		"--subdirs="*)
			((Total[$Current]--))
			SubDirs=${Item#*=}
			echo "Sub-Directories: $SubDirs"
			;;
		*)
			((Counter[$Current]++))

			local File="$Item"

			while [ "${File:0-1}" = "/" ] ; do File=${File%/} ; done

			if [ -d "$File" ] ; then

				### DIRECTORIES ###

				DirName[$Current]=${File##*/}

				if [ "$Recursive" = "yes" ] ; then

					Sort "$File"/*

					if [ "${Mode,,}" = "move" ] ; then

						printf "$RED\nCLEAN:$RESET %s\n" $(rmdir -v "$File")

					fi

				else

					echo "DIR: Skipping!"

				fi

			elif [ -f "$File" ] ; then

				### FILES ###

				### HEADER

				for (( N=1 ; $N < $Current ; N++ )) ; do

					tput cup "$(( $N * 2 - 2 ))" "0"

					printf "$CLEAR\n$GREEN-DIR:$RESET	Level:$N	=> Total:${Total[$N]}	/ Current:${Counter[$N]}	~ ${DirName[$N]##*/}\n"

				done

				### PROCESSES  ###

				printf "$CLEAR\n$GREEN-FILE:$RESET	Level:$Current	=> Total:${Total[$Current]}	/ Current:${Counter[$Current]}\n$GREEN-MANE:$YELLOW	$File$RESET\n"

				### PRE-TEST ###

				local MIME=$(Get_MIME "$File")

				local MIMEMain=${MIME%/*}

				local MIMESub=${MIME#*/}

				printf "\n$YELLOW-MIME:$RESET %s\n" ${MIME^^}

				if [ "$Type" = "" ] || [ "${Type,,}" = "${MIMEMain,,}" ] || [ "${Type,,}" = "${MIMESub,,}" ] ; then

					### PROBE ###

					if [ "${Probe,,}" = "yes" ] ; then

						local OLD=$(Get_SHA256Sum "$Item")

						printf "$YELLOW\n-PROBE:$RESET %s\n" $(mkdir -v -p "PROBE")

						if [ "${Mode,,}" = "copy" ] || [ "${Mode,,}" = "move" ] ; then

							local NEW=""

							printf "$RED\nP-ROBE:$RESET %s\n" $(while [ "$OLD" != "$NEW" ] ; do cp -v -f "$Item" "PROBE/${Item##*/}" ; NEW=$(Get_SHA256Sum "PROBE/${Item##*/}") ; done)

							if [ "${Mode,,}" = "move" ] ; then

								printf "$RED\n-PROBE:$RESET %s\n" $(rm -v -f "$Item")

							fi

							File="PROBE/${File##*/}"

						fi

					fi

					### VARIABLES ###

					### NAMES

					local Name=$(Get_File_Name "$File")

					if [ "$Rename" != "" ] ; then

						case "${Rename,,}" in

						"original")
							;;

						"mime")
							Name=$(printf $MIME | tr '/' '.')
							;;

						"mime-main")
							Name=$MIMEMain
							;;

						"mime-sub")
							Name=$MIMESub
							;;

						"sha256sum")
							Name=$(Get_SHA256Sum "$File")
							;;

						"random")
							Name=$RANDOM$RANDOM$RANDOM$RANDOM
							;;

						*)
							Name=$Rename
							;;

						esac

					fi

					printf "$YELLOW\n-NAME:$RESET %s\n" $Name

					### EXTENSIONS

					local Ext=$(Get_File_Extension "$File")

					if [ "$Extension" != "" ] ; then

						case "${Extension,,}" in

						"original")
							;;

						"mime")
							Ext=$(printf $MIME | tr '/' '.')
							;;

						"mime-main")
							Ext=$MIMEMain
							;;

						"mime-sub")
							Ext=$MIMESub
							;;

						"random")
							Ext=$RANDOM
							;;

						*)
							Ext=$Extension
							;;

						esac

					fi

					printf "$YELLOW\n-EXTENSION:$RESET %s\n" $Ext

					### DIRECTORIES

					local Dir=""

					if [ "$Dirs" != "" ] ; then

						case "${Dirs,,}" in

						"extension")
							if [ "$Ext" = "" ] ; then Dir=$(Get_File_Extension "$File") ; else Dir=${Ext^^} ; fi
							;;

						"mime")
							Dir=${MIME^^}
							;;

						"mime-main")
							Dir=${MIMEMain^^}
							;;

						"mime-sub")
							Dir=${MIMESub^^}
							;;

						"random")
							Dir=$RANDOM$RANDOM
							;;

						*)
							Dir="$Dirs"
							;;

						esac

					fi

					printf "$YELLOW\n-DIRECTORY:$RESET %s\n" $Dir

					### SUB-DIRECTIRIES

					local SubDir=""

					if [ "$SubDirs" != "" ] ; then

						case "${MIMEMain,,}" in

						"image"|"video")

							local WxH="0x0"

							if [ ${MIMEMain,,} = "image" ] ; then WxH=$(Get_Image_WxH "$File") ; fi

							if [ ${MIMEMain,,} = "video" ] ; then WxH=$(Get_Video_WxH "$File") ; fi

							printf "$YELLOW\n-IMAGE (WIDTH x HEIGHT):$RESET %s\n" $WxH

							local FileFormat=$(Get_File_WxH_Format "$WxH")

							case "${SubDirs,,}" in

							"size")

								SubDir="$WxH"
								;;

							"size+format")

								SubDir="$FileFormat/$WxH"
								;;

							"format")

								SubDir="$FileFormat"
								;;

							"format+size")

								SubDir="$FileFormat/$WxH"
								;;

							"random")

								SubDir=$RANDOM$RANDOM
								;;

							*)

								SubDir="$SubDirs"
								;;

							esac

							;;

						*)

							local FileSize=$(Get_File_Size "$File")

							case "${SubDirs,,}" in

							"size")

								local Format=("B" "KB" "MB" "GB" "TB" "PB" "EB" "ZB" "YB" "RB" "QB")

								local Tmp=$FileSize ; N=0 ; while [ "$Tmp" -gt "999" ] ; do ((N++)) ; Tmp=$(( $Tmp / 1000 )) ; done

								SubDir="$Tmp${Format[$N]}"
								;;

							"size+format")

								local Format=("B" "KiB" "MiB" "GiB" "TiB" "PiB" "EiB" "ZiB" "YiB" "RiB" "QiB")

								local Tmp=$FileSize ; N=0 ; while [ "$Tmp" -gt "1023" ] ; do ((N++)) ; Tmp=$(( $Tmp / 1024 )) ; done

								SubDir="$Tmp_${Format[$N]}"
								;;

							"format")

								local Format=("Byte" "KiloByte" "MegaByte" "GigaByte" "TerraByte" "PetaByte" "ExaByte" "ZettaByte" "YottaByte" "RonnaByte" "QuettaByte")

								local Tmp=$FileSize ; N=0 ; while [ "$Tmp" -gt "999" ] ; do ((N++)) ; Tmp=$(( $Tmp / 1000 )) ; done

								SubDir="${Format[$N]}"
								;;

							"format+size")

								local Format=("Byte" "KiloByte" "MegaByte" "GigaByte" "TerraByte" "PetaByte" "ExaByte" "ZettaByte" "YottaByte" "RonnaByte" "QuettaByte")

								local Tmp=$FileSize ; N=0 ; while [ "$Tmp" -gt "999" ] ; do ((N++)) ; Tmp=$(( $Tmp / 1000 )) ; done

								SubDir="${Format[$N]}/$Tmp"
								;;

							"random")

								SubDir=$RANDOM$RANDOM
								;;

							*)

								SubDir="$SubDirs"
								;;

							esac
							;;

						esac

					fi

					printf "$YELLOW\n-SUB-DIRECTORY:$RESET %s\n" $SubDir

					### ACTIONS ###

					### PRE-ACTION

					local Location="./"

					if [ "$Dir" != "" ] && [ "$SubDir" != "" ] ; then

						Location="${Dir^^}/${SubDir^^}"

					elif [ "$Dir" != "" ] ; then

						Location="${Dir^^}"

					elif [ "$SubDir" != "" ] ; then

						Location="${SubDir^^}"

					fi

					local NewName="$Name.$Ext"

					if [ "$Replace" != "yes" ] ; then C=0 ; while [ -e "$Location/$NewName" ] ; do ((C++)) ; NewName="$Name-($C).$Ext" ; done ; fi

					### ACTION

					if [ "${Probe,,}" = "yes" ] || [ "${Mode,,}" = "move" ] ; then

						printf "$BLUE\n--MKDIR:$RESET	%s\n" $( mkdir -v -p "$Location" )

						printf "$BLUE\n--MOVE:$RESET	%s\n" $( mv -v -f "$File" "$Location/$NewName" )

					elif [ "${Mode,,}" = "copy" ] ; then

						printf "$YELLOW\n--MKDIR:$RESET	%s\n" $( mkdir -v -p "$Location" )

						printf "$BLUE\n--COPY:$RESET %s\n" $( cp -v -f "$File" "$Location/$NewName" )

					elif [ "${Mode,,}" = "remove" ] ; then

						printf "$BLUE\n--REMOVE:$RESET %s\n" $( if [ -e "$Location/$NewName" ] ; then rm -v -f "$Location/$NewName" ; else echo "($Location/$NewName) No such file!" ; fi )

					else

						printf "$BLUE\n--DUMMY:$RESET %s --> %s/%s\n" $File $Location $NewName

					fi

				else

					### MISSMATCH ###

					printf "$MAGANTA\n--SKIP:$RESET MIME type does not match! (%s)\n" $MIME

				fi

			else

				### 	UNKNOWN ###

				printf "$RED_YELLOW\n--ERROR:$RESET Unknown file type (\'%s\')\n" $Item

			fi

			### PAUSE ###

			if [ "$Pause" != "" ] ; then

				printf "$YELLOW\n-PAUSE:$RESET %s\n" $Pause

				sleep $Pause

			fi

			;;

		esac

	done

	((Current--))
}

if [ $# -gt 0 ] ; then

	OIFS=$IFS
	IFS=$'\n\b'

	Sort $@

	IFS=$IOFS

else

cat << EOF
${0##*/}
by Ali_ISIN

Version: 2.0

USAGE:

Sort.sh [--Probe] [--Type=(0)] [--Copy|--Move|--Remove] [--Recursive] [--Replace] [--Rename=(1)] [--Extension=(2)] [--Dirs=(3)] [--SubDirs=(4)] [--Pause=(seconds)] List

(0)	Filter by MIME-type [mime]|[mime-main]|[mime-sub] (exp: 'APPLICATION/PDF' or 'VIDEO' or 'GIF')

(1)	Reanme options
	original
	mime
	mime-main
	mime-sub
	sha256sum
	random
	*	'The name desired'

(2)	File-extension options
	original
	mime
	mime-main
	mime-sub
	random
	*	'The name desired'

(3)	Primary directory options
	extension
	mime
	mime-main
	mime-sub
	random
	*	'The name desired'

(4)	Secondary directory options
	size
	size+format
	format
	format+size
	random
	*	'The name desired'

List:	List of directories or files!
EOF

fi
