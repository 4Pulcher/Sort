function MIME_Table(const M: string): string;
begin
    if M = 'text/plain' then Result := 'txt'
    else if M = 'text/x-shellscript' then Result := 'sh'
    else if M = 'text/html' then Result := 'html'
    else if M = 'text/csv' then Result := 'csv'
    else if M = 'application/pdf' then Result := 'pdf'
    else if M = 'application/zip' then Result := 'zip'
    else if M = 'application/gzip' then Result := 'gz'
    else if M = 'application/x-bzip2' then Result := 'bz2'
    else if M = 'application/x-xz' then Result := 'xz'
    else if M = 'application/x-tar' then Result := 'tar'
    else if M = 'image/jpeg' then Result := 'jpg'
    else if M = 'image/png' then Result := 'png'
    else if M = 'image/gif' then Result := 'gif'
    else if M = 'image/webp' then Result := 'webp'
    else if M = 'image/svg+xml' then Result := 'svg'
    else if M = 'audio/mpeg' then Result := 'mp3'
    else if M = 'audio/ogg' then Result := 'ogg'
    else if M = 'audio/flac' then Result := 'flac'
    else if M = 'video/mp4' then Result := 'mp4'
    else if M = 'video/x-matroska' then Result := 'mkv'
    else if M = 'video/webm' then Result := 'webm'
    else if M = 'application/json' then Result := 'json'
    else if M = 'application/xml' then Result := 'xml'
    else if M = 'application/octet-stream' then Result := 'bin'
    else
        Result := '';
end;
