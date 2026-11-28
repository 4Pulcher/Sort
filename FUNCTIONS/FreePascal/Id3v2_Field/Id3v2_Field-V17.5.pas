function Id3v2_Field(const F, Frame: string): string;
var
    FS: TFileStream;
    Hdr: array[0..9] of Byte;
    Ver, TagSize, Off, EndOff, HdrLen, FSize, I: Integer;
    FID: string;
    Payload: string;
    Enc: Byte;
begin
    Result := '';
    if not Id3v2_Present(F) then
        Exit;
    Ver := Id3v2_Major(F);
    TagSize := Id3v2_Tag_Size(F);
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        Off := 10;
        EndOff := 10 + TagSize;
        while Off < EndOff do
        begin
            FS.Position := Off;
            if FS.Read(Hdr, 10) < 10 then
                Break;
            if Ver = 2 then
            begin
                { v2.2: 3-char frame id, 3-byte big-endian size, no flags }
                HdrLen := 6;
                FID := '';
                for I := 0 to 2 do
                    FID := FID + Chr(Hdr[I]);
                if not (Hdr[0] in [Ord('A')..'Z', Ord('0')..'9']) then
                    Break;
                FSize := (Hdr[3] shl 16) or (Hdr[4] shl 8) or Hdr[5];
            end
            else
            begin
                HdrLen := 10;
                FID := '';
                for I := 0 to 3 do
                    FID := FID + Chr(Hdr[I]);
                if not (Hdr[0] in [Ord('A')..'Z', Ord('0')..'9']) then
                    Break;
                if Ver >= 4 then
                    FSize := (Hdr[4] shl 21) or (Hdr[5] shl 14) or (Hdr[6] shl 7) or Hdr[7]
                else
                    FSize := (Hdr[4] shl 24) or (Hdr[5] shl 16) or (Hdr[6] shl 8) or Hdr[7];
            end;
            if (FSize <= 0) or (Off + HdrLen + FSize > FS.Size) then
                Break;

            if FID = Frame then
            begin
                SetLength(Payload, FSize);
                FS.Position := Off + HdrLen;
                FS.ReadBuffer(Payload[1], FSize);
                Enc := Ord(Payload[1]);
                Delete(Payload, 1, 1);
                case Enc of
                    1: Result := Trim_Tags(Utf16_To_Utf8(Payload, False));
                    2: Result := Trim_Tags(Utf16_To_Utf8(Payload, True));
                    0: Result := Trim_Tags(Latin1_To_Utf8(Payload));
                else
                    Result := Trim_Tags(Payload);
                end;
                Exit;
            end;
            Off := Off + HdrLen + FSize;
        end;
    finally
        FS.Free;
    end;
end;
