function Fs_Broken(const Parts: TFsPartArray; Idx: Integer;
    Hit, Size: Int64): Boolean;
var
    I: Integer;
begin
    Result := False;
    if Hit + Size > Parts[Idx].StartV + Parts[Idx].SizeV then
        Exit(True);
    for I := 0 to Length(Parts) - 1 do
    begin
        if I = Idx then
            Continue;
        if (Hit < Parts[I].StartV + Parts[I].SizeV) and
           (Hit + Size > Parts[I].StartV) then
            Exit(True);
    end;
end;
