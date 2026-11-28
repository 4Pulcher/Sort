function Id3v1_Present(const F: string): Boolean;
var
    FS: TFileStream;
    Buf: array[0..2] of Byte;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        if FS.Size < 128 then
            Exit;
        FS.Position := FS.Size - 128;
        FS.ReadBuffer(Buf, 3);
        Result := (Buf[0] = Ord('T')) and (Buf[1] = Ord('A')) and (Buf[2] = Ord('G'));
    finally
        FS.Free;
    end;
end;
