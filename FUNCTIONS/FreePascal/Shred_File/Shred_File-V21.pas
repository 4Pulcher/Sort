procedure Shred_File(const F: string);
var
    FS   : TFileStream;
    Buf  : array[1..4096] of Byte;
    Left : Int64;
    I    : Integer;
    Dummy: string;
begin
    if HaveTool('shred') then
    begin
        RunTool('shred', ['-u', '-n', '1', F], Dummy);
        Exit;
    end;
    { Manual fallback: overwrite once with random bytes, then delete }
    try
        FS := TFileStream.Create(F, fmOpenReadWrite);
        try
            Left := FS.Size;
            while Left > 0 do
            begin
                for I := 1 to SizeOf(Buf) do
                    Buf[I] := Random(256);
                if Left < SizeOf(Buf) then
                    FS.Write(Buf, Left)
                else
                    FS.Write(Buf, SizeOf(Buf));
                Dec(Left, Min(SizeOf(Buf), Left));
            end;
        finally
            FS.Free;
        end;
    except
        { unreadable file: fall through to plain delete }
    end;
    DeleteFile(F);
end;
