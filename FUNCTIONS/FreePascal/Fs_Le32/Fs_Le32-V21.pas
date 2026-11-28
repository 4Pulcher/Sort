function Fs_Le32(const H: string; C: Integer): Int64;
var
    K: Integer;
    B: Int64;
begin
    Result := 0;
    for K := 0 to 3 do
    begin
        B := StrToIntDef('$' + Copy(H, C + K * 2, 2), 0);
        Result := Result + (B shl (8 * K));
    end;
end;
