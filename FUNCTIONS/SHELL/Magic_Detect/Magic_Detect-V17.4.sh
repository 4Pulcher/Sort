Magic_Detect() {
	local H=${1,,}
	case "$H" in
	25504446*)                         printf 'PDF|pdf' ;;
	89504e47*)                         printf 'PNG|png' ;;
	ffd8ff*)                           printf 'JPEG|jpg,jpeg,jfif' ;;
	47494638*)                         printf 'GIF|gif' ;;
	424d*)                             printf 'BMP|bmp' ;;
	52494646*5745425?*)                printf 'WEBP|webp' ;;
	52494646*57415645*)                printf 'WAV|wav' ;;
	1a45dfa3*)                         printf 'MKV/WEBM|mkv,webm,mka' ;;
	????????66747970*)                 printf 'MP4/MOV|mp4,mov,m4a,3gp' ;;
	494433*)                           printf 'MP3 (ID3)|mp3' ;;
	fffb*|fff3*|fff2*|ffe3*)           printf 'MP3 (MPEG)|mp3' ;;
	4f676753*)                         printf 'OGG|ogg,oga,opus' ;;
	664c6143*)                         printf 'FLAC|flac' ;;
	504b0304*|504b0506*|504b0708*)     printf 'ZIP/Office|zip,docx,xlsx,pptx,odt,jar,apk,epub' ;;
	377abcaf271c*)                     printf '7-Zip|7z' ;;
	5261727?1a*)                       printf 'RAR|rar' ;;
	1f8b*)                             printf 'GZIP|gz,tgz' ;;
	425a68*)                           printf 'BZIP2|bz2,tbz2' ;;
	fd377a585a*)                       printf 'XZ|xz,txz' ;;
	28b52ffd*)                         printf 'ZSTD|zst' ;;
	7f454c46*)                         printf 'ELF binary|so,bin' ;;
	53514c69746520666f726d61742033*)  printf 'SQLite|db,sqlite' ;;
	cafebabe*)                         printf 'Java class|class' ;;
	2321*)                             printf 'Script (#!)|sh,py,pl,rb' ;;
	7ffe*)                             printf 'Bourne shell archive|shar' ;;
	*)                                 return 1 ;;
	esac
}
