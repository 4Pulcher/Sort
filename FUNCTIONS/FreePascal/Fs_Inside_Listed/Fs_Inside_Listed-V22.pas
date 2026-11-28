function Fs_Inside_Listed(const Parts: TFsPartArray; Off: Int64): Boolean;
var
    I: Integer;
begin
    Result := False;
    for I := 0 to Length(Parts) - 1 do
        if Parts[I].Listed and (Off >= Parts[I].StartV) and
           (Off < Parts[I].StartV + Parts[I].SizeV) then
            Exit(True);
end;
