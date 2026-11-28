procedure Magic_Detect(const H: string; out Name: string; out Exts: string);
begin
    Name := '?';
    Exts := '';
    if H = '' then
        Exit;
    { offset signatures }
    if Magic_Has(H, '52494646') and (Copy(H, 17, 8) = '57454250') then
    begin Name := 'WEBP'; Exts := 'webp'; Exit; end;
    if Magic_Has(H, '52494646') and (Copy(H, 17, 8) = '57415645') then
    begin Name := 'WAV'; Exts := 'wav'; Exit; end;
    if (Length(H) >= 16) and (Copy(H, 9, 8) = '66747970') then
    begin Name := 'MP4/MOV'; Exts := 'mp4,mov,m4a,3gp'; Exit; end;
    { prefix signatures }
    if Magic_Has(H, '25504446') then begin Name := 'PDF'; Exts := 'pdf'; Exit; end;
    if Magic_Has(H, '89504e47') then begin Name := 'PNG'; Exts := 'png'; Exit; end;
    if Magic_Has(H, 'ffd8ff')   then begin Name := 'JPEG'; Exts := 'jpg,jpeg,jfif'; Exit; end;
    if Magic_Has(H, '47494638') then begin Name := 'GIF'; Exts := 'gif'; Exit; end;
    if Magic_Has(H, '424d')     then begin Name := 'BMP'; Exts := 'bmp'; Exit; end;
    if Magic_Has(H, '1a45dfa3') then begin Name := 'MKV/WEBM'; Exts := 'mkv,webm,mka'; Exit; end;
    if Magic_Has(H, '494433')   then begin Name := 'MP3 (ID3)'; Exts := 'mp3'; Exit; end;
    if Magic_Has(H, 'fffb') or Magic_Has(H, 'fff3') or Magic_Has(H, 'fff2') then
        begin Name := 'MP3 (MPEG)'; Exts := 'mp3'; Exit; end;
    if Magic_Has(H, '4f676753') then begin Name := 'OGG'; Exts := 'ogg,oga,opus'; Exit; end;
    if Magic_Has(H, '664c6143') then begin Name := 'FLAC'; Exts := 'flac'; Exit; end;
    if Magic_Has(H, '504b0304') or Magic_Has(H, '504b0506') or Magic_Has(H, '504b0708') then
        begin Name := 'ZIP/Office'; Exts := 'zip,docx,xlsx,pptx,odt,jar,apk,epub'; Exit; end;
    if Magic_Has(H, '377abcaf271c') then begin Name := '7-Zip'; Exts := '7z'; Exit; end;
    if Magic_Has(H, '5261727') then begin Name := 'RAR'; Exts := 'rar'; Exit; end;
    if Magic_Has(H, '1f8b')   then begin Name := 'GZIP'; Exts := 'gz,tgz'; Exit; end;
    if Magic_Has(H, '425a68') then begin Name := 'BZIP2'; Exts := 'bz2,tbz2'; Exit; end;
    if Magic_Has(H, 'fd377a585a') then begin Name := 'XZ'; Exts := 'xz,txz'; Exit; end;
    if Magic_Has(H, '28b52ffd') then begin Name := 'ZSTD'; Exts := 'zst'; Exit; end;
    if Magic_Has(H, '7f454c46') then begin Name := 'ELF binary'; Exts := 'so,bin'; Exit; end;
    if Magic_Has(H, '53514c69746520666f726d61742033') then
        begin Name := 'SQLite'; Exts := 'db,sqlite'; Exit; end;
    if Magic_Has(H, 'cafebabe') then begin Name := 'Java class'; Exts := 'class'; Exit; end;
    if Magic_Has(H, '2321')   then begin Name := 'Script (#!)'; Exts := 'sh,py,pl,rb'; Exit; end;
end;
