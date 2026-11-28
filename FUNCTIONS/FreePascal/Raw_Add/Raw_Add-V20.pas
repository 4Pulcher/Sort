procedure Raw_Add(Off: Integer; const Sig, Name, Exts: string);
var
    N: Integer;
    BestLen, BestStart, I, J, E2, S: Integer;
begin
    N := Length(RawEntries);
    SetLength(RawEntries, N + 1);
    RawEntries[N].Off := Off;
    RawEntries[N].Sig := Sig;
    RawEntries[N].Name := Name;
    RawEntries[N].Exts := Exts;
    if Pos('?', Sig) = 0 then
    begin
        RawEntries[N].AnchorHex := Sig;
        RawEntries[N].AnchorNibble := 0;
        Exit;
    end;
    { longest even-aligned even-length known run (>= 4 hex) }
    BestLen := 0; BestStart := -1;
    I := 1;
    while I <= Length(Sig) do
    begin
        if Sig[I] = '?' then
        begin
            Inc(I);
            Continue;
        end;
        J := I;
        while (J <= Length(Sig)) and (Sig[J] <> '?') do
            Inc(J);
        for S := I to J - 1 do
        begin
            E2 := J - 1;
            while ((E2 - S + 1) mod 2) <> 0 do
                Dec(E2);
            if ((S - 1) mod 2 = 0) and (E2 - S + 1 >= BestLen)
                and (E2 - S + 1 >= 4) then
            begin
                BestLen := E2 - S + 1;
                BestStart := S;
            end;
        end;
        I := J;
    end;
    if BestStart < 0 then
    begin
        { cannot anchor: skip by giving it an impossible anchor }
        RawEntries[N].AnchorHex := '';
        RawEntries[N].AnchorNibble := 0;
    end
    else
    begin
        RawEntries[N].AnchorHex := Copy(Sig, BestStart, BestLen);
        RawEntries[N].AnchorNibble := BestStart - 1;
    end;
end;
