procedure Raw_CarveSize(const H: string; const Name: string;
    out Size: Int64; out Exact: Boolean);
var
    Pos1, P, EndPos: Integer;
    Clen: Int64;
    CType: string;
begin
    Size := Length(H) div 2;
    Exact := False;
    if Size > Raw_CarveMax then
        Size := Raw_CarveMax;
    if Copy(Name, 1, 9) = 'PNG image' then
    begin
        Pos1 := 8;
        while Pos1 * 2 + 24 <= Length(H) do
        begin
            Clen := Raw_HexVal(Copy(H, Pos1 * 2 + 1, 8));
            CType := Copy(H, Pos1 * 2 + 9, 8);
            Pos1 := Pos1 + 12 + Clen;   { len + type + data + CRC }
            if CType = '49454e44' then
            begin
                Size := Pos1;
                Exact := True;
                Break;
            end;
            if Clen > Length(H) div 2 then
            begin
                Size := Pos1;
                Break;
            end;
        end;
    end
    else if Copy(Name, 1, 10) = 'JPEG image' then
    begin
        P := Raw_LastPos(H, 'ffd9', 1);
        if P > 0 then
        begin
            Size := (P - 1) div 2 + 2;
            Exact := True;
        end;
    end
    else if Copy(Name, 1, 9) = 'GIF image' then
    begin
        P := Raw_LastPos(H, '3b', 27);
        if P > 0 then
        begin
            Size := (P - 1) div 2 + 1;
            Exact := True;
        end;
    end
    else if (Copy(Name, 1, 4) = 'ZIP/') or (Copy(Name, 1, 11) = 'ZIP archive') then
    begin
        P := Raw_LastPos(H, '504b0506', 1);
        if P > 0 then
        begin
            EndPos := (P - 1) div 2;
            if EndPos + 22 <= Length(H) div 2 then
            begin
                Size := EndPos + 22
                    + Raw_HexVal(Copy(H, EndPos * 2 + 41, 2))
                    + Raw_HexVal(Copy(H, EndPos * 2 + 43, 2)) * 256;
                Exact := True;
            end;
        end;
    end
    else if Copy(Name, 1, 12) = 'PDF document' then
    begin
        P := Raw_LastPos(H, '2525454f46', 1);
        if P > 0 then
        begin
            Size := (P - 1) div 2 + 5;
            Exact := True;
        end;
    end;
    if Size > Raw_CarveMax then
        Size := Raw_CarveMax;
end;
