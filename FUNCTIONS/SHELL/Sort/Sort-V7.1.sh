Sort() {
	((Current++))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		case "${Item,,}" in
		--pause=*)
			((Total[$Current]--))
			Pause=${Item#*=}
			;;
		--type=*)
			((Total[$Current]--))
			Type=${Item#*=}
			;;
		--mode=*)
			((Total[$Current]--))
			Mode=${Item#*=}
			;;
		--recursive)
			((Total[$Current]--))
			Recursive=yes
			;;
		--replace)
			((Total[$Current]--))
			Replace=yes
			;;
		--rename=*)
			((Total[$Current]--))
			Rename=${Item#*=}
			;;
		--title)
			((Total[$Current]--))
			Title=yes
			;;
		--extension=*)
			((Total[$Current]--))
			Extension=${Item#*=}
			;;
		--dirs=*)
			((Total[$Current]--))
			Dirs=${Item#*=}
			;;
		--subdirs=*)
			((Total[$Current]--))
			SubDirs=${Item#*=}
			;;
		*)
			((Counter[$Current]++))

			printf 'PROGRESS'
			for ((i = 1; i <= Current; i++)); do
				printf ' ~ [%d]=%d/%d' "$i" "${Counter[$i]}" "${Total[$i]}"
			done
			printf '\n'

			if [[ ! -e "$Item" ]]; then
				printf 'SKIP: Missing %s\n' "$Item"
				continue
			fi

			if [[ -L "$Item" ]]; then
				printf 'SKIP: Symlink %s\n' "$Item"
				continue
			fi

			if [[ -d "$Item" ]]; then
				Draw_Line '='

				if [[ "$Recursive" == yes ]]; then
					printf "$BOLDBLUE DIR:$YELLOW %s$RESET\n" "$Item"
					Draw_Line '>'
					Sort "$Item"/*

					if [[ "$Mode" == move ]]; then
						if rmdir "$Item" 2>/dev/null; then
							printf "$BLUE CLEANUP:$RESET %s\n" "$Item"
						else
							printf "$RED ERROR:$RESET Directory not empty: %s\n" "$Item"
						fi
					fi
				else
					printf "$RED DIR:$RESET Skipping!\n"
				fi

				Draw_Line '='
				continue
			fi

			if [[ -f "$Item" ]]; then
				Draw_Line '-'
				printf "$BOLDGREEN FILE:$YELLOW %s$RESET\n" "$Item"

				MIME=$(Get_MIME "$Item")
				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}

				printf "$YELLOW MIME:$RESET %s\n" "$MIME"

				if [[ -n "$Type" && "${MIME^^}" != *"${Type^^}"* ]]; then
					continue
				fi

				local D SD LOC NAME EXT NEWNAME COUNT BASENAME

				D=$(Resolve_Path_Segment "$Dirs" "$Item")
				SD=$([[ -n "$SubDirs" ]] && Resolve_Path_Segment "$SubDirs" "$Item")

				LOC='.'
				[[ -n "$D" ]] && LOC="${D^^}"
				[[ -n "$SD" ]] && LOC="$LOC/${SD^^}"

				printf "$YELLOW TARGET:$RESET %s\n" "$LOC"

				if [[ -n "$Title" ]]; then
					case "$MIMEMain" in
					application) NAME=$(Get_Doc_Title "$Item") ;;
					image) NAME=$(Get_Image_Meta "$Item") ;;
					audio) NAME=$(Get_Audio_Info "$Item") ;;
					video) NAME=$(Get_Video_Title "$Item") ;;
					esac
				fi

				[[ -z "$NAME" ]] && NAME=$(Get_File_Name "$Item")
				[[ -n "$Rename" ]] && NAME=$(Resolve_Path_Segment "$Rename" "$Item")

				EXT=$(Get_File_Ext "$Item")

				if [[ -n "$Extension" ]]; then
					EXT=$(Resolve_Path_Segment "$Extension" "$Item")
					EXT=${EXT,,}
					EXT=${EXT//\//.}
					EXT=${EXT// /_}
				fi

				NEWNAME="$NAME.$EXT"

				if [[ -z "$Replace" || -z "$Title" ]]; then
					COUNT=0
					BASENAME="$NAME"

					while [[ -e "$LOC/$NEWNAME" ]]; do
						((COUNT++))
						NEWNAME="$BASENAME-($COUNT).$EXT"
					done
				fi

				printf "$YELLOW NEW-NAME:$RESET %s\n" "$NEWNAME"

				if [[ -n "$Mode" ]]; then
					mkdir -p "$LOC"

					case "$Mode" in
					move)
						printf "$RED MOVE:$RESET %s\n" "$(mv -vf "$Item" "$LOC/$NEWNAME" 2>&1)"
						;;

					copy)
						printf "$RED COPY:$RESET %s\n" "$(cp -vf "$Item" "$LOC/$NEWNAME" 2>&1)"
						;;

					remove)
						printf "$RED REMOVE:$RESET %s\n" "$(trash-put -v "$Item" 2>&1)"
						;;
					esac
				else
					printf "$GREEN TEST:$RESET %s -> %s/%s\n" "$Item" "$LOC" "$NEWNAME"
				fi

				[[ -n "$Pause" ]] && sleep "$Pause"
				Draw_Line '-'
			fi
			;;
		esac
	done

	((Current--))
}
