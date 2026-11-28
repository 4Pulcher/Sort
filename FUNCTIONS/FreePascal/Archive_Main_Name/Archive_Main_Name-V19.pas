function Archive_Main_Name(const F: string): string;
var
    U: TUnZipper;
    I, K: Integer;
    Entry, Top, Res, Common: string;
begin
    Result := '';
    if Is_Zip_File(F) then
    begin
        U := TUnZipper.Create;
        try
            U.FileName := F;
            U.Examine;
            if U.Entries.Count = 1 then
            begin
                Entry := U.Entries[0].ArchiveFileName;
                Result := ChangeFileExt(ExtractFileName(Entry), '');
                Exit;
            end;
            Common := '';
            for I := 0 to U.Entries.Count - 1 do
            begin
                Entry := U.Entries[I].ArchiveFileName;
                K := Pos('/', Entry);
                if K = 0 then
                    Exit;  { loose files: ambiguous }
                Top := Copy(Entry, 1, K - 1);
                if Common = '' then
                    Common := Top
                else if Common <> Top then
                    Exit;  { several top-level dirs: ambiguous }
            end;
            Result := Common;
        finally
            U.Free;
        end;
        Exit;
    end;
    if HaveTool('tar') then
    begin
        if RunTool('tar', ['-tf', F], Res) <> 0 then
            Exit;
        Common := '';
        I := 1;
        while I <= Length(Res) do
        begin
            K := Pos(#10, Copy(Res, I, MaxInt));
            if K = 0 then
            begin
                Entry := Copy(Res, I, MaxInt);
                I := Length(Res) + 1;
            end
            else
            begin
                Entry := Copy(Res, I, K - 1);
                I := I + K;
            end;
            Entry := Trim(Entry);
            if Entry = '' then
                Continue;
            K := Pos('/', Entry);
            if K = 0 then
                Exit;
            Top := Copy(Entry, 1, K - 1);
            if Common = '' then
                Common := Top
            else if Common <> Top then
                Exit;
        end;
        Result := Common;
    end;
end;
