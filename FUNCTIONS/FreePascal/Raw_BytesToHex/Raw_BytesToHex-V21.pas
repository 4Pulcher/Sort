function Raw_BytesToHex(const B: array of Byte; N: Integer): string;
var
    I: Integer;
begin
    Result := '';
    SetLength(Result, N * 2);
    for I := 0 to N - 1 do
    begin
        Result[I * 2 + 1] := RawHexChars[B[I] div 16 + 1];
        Result[I * 2 + 2] := RawHexChars[B[I] mod 16 + 1];
    end;
end;
