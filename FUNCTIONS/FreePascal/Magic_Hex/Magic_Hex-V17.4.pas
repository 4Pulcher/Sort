function Magic_Hex(const Path: string): string;
var
    F: TFileStream;
    Buf: array[0..15] of Byte;
    N: Integer;
    I: Integer;
begin
    Result := '';
    try
        F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
        try
            N := F.Read(Buf, 16);
            for I := 0 to N - 1 do
                Result := Result + LowerCase(IntToHex(Buf[I], 2));
        finally
            F.Free;
        end;
    except
        Result := '';
    end;
end;
