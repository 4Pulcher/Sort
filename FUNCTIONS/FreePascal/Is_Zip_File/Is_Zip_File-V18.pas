function Is_Zip_File(const F: string): Boolean;
var
    FS: TFileStream;
    Sig: array[1..4] of Byte;
    N: Integer;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    try
        FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
        try
            if FS.Size < 4 then
                Exit;
            N := FS.Read(Sig, 4);
            Result := (N = 4) and (Sig[1] = $50) and (Sig[2] = $4B)
                      and ((Sig[3] = $03) or (Sig[3] = $05) or (Sig[3] = $07));
        finally
            FS.Free;
        end;
    except
        Result := False;
    end;
end;
