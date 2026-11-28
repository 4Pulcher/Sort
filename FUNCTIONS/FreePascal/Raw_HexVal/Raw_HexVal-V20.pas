function Raw_HexVal(const H: string): Int64;
var
    I: Integer;
    D: Int64;
begin
    Result := 0;
    for I := 1 to Length(H) do
    begin
        case H[I] of
            '0'..'9': D := Ord(H[I]) - Ord('0');
            'a'..'f': D := Ord(H[I]) - Ord('a') + 10;
        else
            D := 0;
        end;
        Result := Result * 16 + D;
    end;
end;
