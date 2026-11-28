function Id3v2_Present(const F: string): Boolean;
var
    FS: TFileStream;
    Buf: array[0..2] of Byte;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        if FS.Size < 10 then
            Exit;
        FS.ReadBuffer(Buf, 3);
        Result := (Buf[0] = Ord('I')) and (Buf[1] = Ord('D')) and (Buf[2] = Ord('3'));
    finally
        FS.Free;
    end;
end;
