Lang_Name() {
	case "$1" in
		en) printf '%s' 'English' ;;
		zh) printf '%s' 'Chinese (Mandarin) / 中文' ;;
		hi) printf '%s' 'Hindi / हिन्दी' ;;
		es) printf '%s' 'Spanish / Español' ;;
		fr) printf '%s' 'French / Français' ;;
		ar) printf '%s' 'Arabic / العربية' ;;
		bn) printf '%s' 'Bengali / বাংলা' ;;
		pt) printf '%s' 'Portuguese / Português' ;;
		ru) printf '%s' 'Russian / Русский' ;;
		ur) printf '%s' 'Urdu / اردو' ;;
		id) printf '%s' 'Indonesian / Bahasa Indonesia' ;;
		de) printf '%s' 'German / Deutsch' ;;
		ja) printf '%s' 'Japanese / 日本語' ;;
		tr) printf '%s' 'Turkish / Türkçe' ;;
		ko) printf '%s' 'Korean / 한국어' ;;
		vi) printf '%s' 'Vietnamese / Tiếng Việt' ;;
		it) printf '%s' 'Italian / Italiano' ;;
		pl) printf '%s' 'Polish / Polski' ;;
		nl) printf '%s' 'Dutch / Nederlands' ;;
		fa) printf '%s' 'Persian / فارسی' ;;
		*) printf '%s' "$1" ;;
	esac
}
