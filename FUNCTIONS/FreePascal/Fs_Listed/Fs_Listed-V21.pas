procedure Fs_Listed(S: TFileStream; Fsize: Int64; var Parts: TFsPartArray);
var
    H, G: string;
    Buf: array of Byte;
    N, I, K, Tb: Integer;
    Lba, Nsec, Start, Size, Elba, Nent, Esz, First, Last: Int64;
    Any: Boolean;
begin
    SetLength(Parts, 0);
    SetLength(Buf, 512);
    S.Seek(0, soFromBeginning);
    N := S.Read(Buf[0], 512);
    if N <> 512 then
        Exit;
    H := Raw_BytesToHex(Buf, 512);
    if Copy(H, 1021, 4) <> '55aa' then
        Exit;
    { GPT protective MBR? }
    if (Copy(H, 893, 2) = 'ee') or (Copy(H, 925, 2) = 'ee') or
       (Copy(H, 957, 2) = 'ee') or (Copy(H, 989, 2) = 'ee') then
    begin
        SetLength(Buf, 512);
        S.Seek(512, soFromBeginning);
        N := S.Read(Buf[0], 512);
        if N <> 512 then
            Exit;
        G := Raw_BytesToHex(Buf, 512);
        if Copy(G, 1, 16) = '4546492050415254' then
        begin
            Elba := Fs_Le64(G, 145);
            Nent := Fs_Le32(G, 161);
            Esz := Fs_Le32(G, 169);
            if (Esz >= 128) and (Nent > 0) and (Nent * Esz <= 4 * 1024 * 1024) then
            begin
                SetLength(Buf, Nent * Esz);
                S.Seek(Elba * 512, soFromBeginning);
                N := S.Read(Buf[0], Nent * Esz);
                if N = Nent * Esz then
                begin
                    G := Raw_BytesToHex(Buf, N);
                    for K := 0 to Nent - 1 do
                    begin
                        Any := False;
                        for I := 1 to 32 do
                            if G[K * Esz * 2 + I] <> '0' then
                                Any := True;
                        if not Any then
                            Continue;
                        First := Fs_Le64(G, K * Esz * 2 + 65);
                        Last := Fs_Le64(G, K * Esz * 2 + 81);
                        if Last < First then
                            Continue;
                        Start := First * 512;
                        Size := (Last - First + 1) * 512;
                        if (Size > 0) and (Start + Size <= Fsize) then
                        begin
                            SetLength(Parts, Length(Parts) + 1);
                            Parts[Length(Parts) - 1].StartV := Start;
                            Parts[Length(Parts) - 1].SizeV := Size;
                            Parts[Length(Parts) - 1].Fs := '';
                            Parts[Length(Parts) - 1].Listed := True;
                        end;
                    end;
                end;
            end;
            Exit;
        end;
    end;
    { classic MBR entries }
    for I := 0 to 3 do
    begin
        Tb := StrToIntDef('$' + Copy(H, (446 + 16 * I + 5) * 2, 2), 0);
        if (Tb = 0) or (Tb = 5) or (Tb = 15) or (Tb = 85) or (Tb = 238) then
            Continue;
        Lba := Fs_Le32(H, (446 + 16 * I + 9) * 2);
        Nsec := Fs_Le32(H, (446 + 16 * I + 13) * 2);
        if Nsec <= 0 then
            Continue;
        Start := Lba * 512;
        Size := Nsec * 512;
        if Start + Size <= Fsize then
        begin
            SetLength(Parts, Length(Parts) + 1);
            Parts[Length(Parts) - 1].StartV := Start;
            Parts[Length(Parts) - 1].SizeV := Size;
            Parts[Length(Parts) - 1].Fs := '';
            Parts[Length(Parts) - 1].Listed := True;
        end;
    end;
end;
