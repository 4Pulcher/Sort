function Get_Audio_Tags_Dir(const F: string): string;
var
    A, Y, Al, Sub: string;
begin
    Result := '';
    A := Tags_Sanitize(Id3_Field(F, 'artist'));
    Y := Id3_Field(F, 'year');
    Al := Tags_Sanitize(Id3_Field(F, 'album'));
    if (Y <> '') and (Al <> '') then
        Sub := Y + ' - ' + Al
    else
        Sub := Y + Al;
    if A <> '' then
        Result := A;
    if Sub <> '' then
    begin
        if Result <> '' then
            Result := Result + '/' + Sub
        else
            Result := Sub;
    end;
end;
