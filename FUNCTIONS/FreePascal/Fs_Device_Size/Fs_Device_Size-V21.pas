function Fs_Device_Size(S: TFileStream): Int64;
begin
    Result := S.Size;
    if Result > 0 then
        Exit;
    Result := 0;
{$IFDEF LINUX}
    try
        if FpIoctl(LongInt(S.Handle), $80081272, Result) <> 0 then
            Result := 0;
    except
        Result := 0;
    end;
{$ENDIF}
end;
