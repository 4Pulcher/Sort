function Utf16_To_Utf8(const S: string; BE: Boolean): string;
var
    WS: WideString;
    I, N: Integer;
    W: Word;
    Swap: Boolean;
begin
    Result := '';
    N := Length(S) div 2;
    if N = 0 then
        Exit;
    Swap := False;
    SetLength(WS, N);
    for I := 0 to N - 1 do
    begin
        if BE then
            W := (Ord(S[I * 2 + 1]) shl 8) or Ord(S[I * 2 + 2])
        else
            W := (Ord(S[I * 2 + 2]) shl 8) or Ord(S[I * 2 + 1]);
        if (I = 0) and ((W = $FEFF) or (W = $FFFE)) then
        begin
            { byte order mark - remember the real order, skip the mark }
            if ((W = $FFFE) and (not BE)) or ((W = $FEFF) and BE) then
                Swap := True;
            continue;
        end;
        if Swap then
            W := (W shl 8) or (W shr 8);
        WS[I + 1] := WideChar(W);
    end;
    Result := Utf8Encode(WS);
end;
