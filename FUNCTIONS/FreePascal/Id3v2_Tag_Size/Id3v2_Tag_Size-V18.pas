function Id3v2_Tag_Size(const F: string): Integer;
var
    FS: TFileStream;
    Buf: array[0..3] of Byte;
begin
    Result := 0;
    if not Id3v2_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := 6;
        FS.ReadBuffer(Buf, 4);
        Result := (Buf[0] shl 21) or (Buf[1] shl 14) or (Buf[2] shl 7) or Buf[3];
    finally
        FS.Free;
    end;
end;
