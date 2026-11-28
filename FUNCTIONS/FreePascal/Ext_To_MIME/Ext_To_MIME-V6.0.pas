function Ext_To_MIME(const E: string): string;
begin
    if E = 'txt' then Result := 'text/plain'
    else if E = 'sh' then Result := 'text/x-shellscript'
    else if E = 'html' then Result := 'text/html'
    else if E = 'pdf' then Result := 'application/pdf'
    else if E = 'zip' then Result := 'application/zip'
    else if E = 'gz' then Result := 'application/gzip'
    else if E = 'jpg' then Result := 'image/jpeg'
    else if E = 'jpeg' then Result := 'image/jpeg'
    else if E = 'png' then Result := 'image/png'
    else if E = 'gif' then Result := 'image/gif'
    else if E = 'mp3' then Result := 'audio/mpeg'
    else if E = 'mp4' then Result := 'video/mp4'
    else if E = 'json' then Result := 'application/json'
    else
        Result := '';
end;
