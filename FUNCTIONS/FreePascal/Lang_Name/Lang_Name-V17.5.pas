function Lang_Name(const Code: String): String;
begin
    if Code = 'en' then Result := 'English'
    else if Code = 'zh' then Result := 'Chinese (Mandarin) / 中文'
    else if Code = 'hi' then Result := 'Hindi / हिन्दी'
    else if Code = 'es' then Result := 'Spanish / Español'
    else if Code = 'fr' then Result := 'French / Français'
    else if Code = 'ar' then Result := 'Arabic / العربية'
    else if Code = 'bn' then Result := 'Bengali / বাংলা'
    else if Code = 'pt' then Result := 'Portuguese / Português'
    else if Code = 'ru' then Result := 'Russian / Русский'
    else if Code = 'ur' then Result := 'Urdu / اردو'
    else if Code = 'id' then Result := 'Indonesian / Bahasa Indonesia'
    else if Code = 'de' then Result := 'German / Deutsch'
    else if Code = 'ja' then Result := 'Japanese / 日本語'
    else if Code = 'tr' then Result := 'Turkish / Türkçe'
    else if Code = 'ko' then Result := 'Korean / 한국어'
    else if Code = 'vi' then Result := 'Vietnamese / Tiếng Việt'
    else if Code = 'it' then Result := 'Italian / Italiano'
    else if Code = 'pl' then Result := 'Polish / Polski'
    else if Code = 'nl' then Result := 'Dutch / Nederlands'
    else if Code = 'fa' then Result := 'Persian / فارسی'
    else Result := Code;
end;
