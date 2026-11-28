function Id3v2_Major(const F: string): Integer;
var
    FS: TFileStream;
    B: Byte;
begin
    Result := 0;
    if not Id3v2_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := 3;
        FS.ReadBuffer(B, 1);
        Result := B;
    finally
        FS.Free;
    end;
end;
