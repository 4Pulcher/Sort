function Id3_Field(const F, Field: string): string;
var
    Field_L: string;
begin
    Result := '';
    Field_L := LowerCase(Field);
    case Field_L of
        'title':
            Result := Id3v2_Field(F, 'TIT2');
        'artist':
            Result := Id3v2_Field(F, 'TPE1');
        'album':
            Result := Id3v2_Field(F, 'TALB');
        'year':
        begin
            Result := Id3v2_Field(F, 'TDRC');
            if Result = '' then
                Result := Id3v2_Field(F, 'TYER');
        end;
        'genre':
            Result := Id3v2_Field(F, 'TCON');
        'track':
            Result := Id3v2_Field(F, 'TRCK');
    else
        Exit;
    end;

    { v2.2 3-character ids }
    if Result = '' then
        case Field_L of
            'title': Result := Id3v2_Field(F, 'TT2');
            'artist': Result := Id3v2_Field(F, 'TP1');
            'album': Result := Id3v2_Field(F, 'TAL');
            'year': Result := Id3v2_Field(F, 'TYE');
            'genre': Result := Id3v2_Field(F, 'TCO');
            'track': Result := Id3v2_Field(F, 'TRK');
        end;

    { ID3v1 fallback }
    if Result = '' then
        Result := Id3v1_Field(F, Field_L);

    { genre: "(17)" or plain "17" -> genre name }
    if (Field_L = 'genre') and (Result <> '') then
    begin
        if (Length(Result) > 2) and (Result[1] = '(') then
            Result := Copy(Result, 2, Pos(')', Result) - 2);
        if Result = IntToStr(StrToIntDef(Result, -1)) then
        begin
            if Id3v1_Genre_Name(StrToIntDef(Result, -1)) <> '' then
                Result := Id3v1_Genre_Name(StrToIntDef(Result, -1));
        end;
    end;
end;
