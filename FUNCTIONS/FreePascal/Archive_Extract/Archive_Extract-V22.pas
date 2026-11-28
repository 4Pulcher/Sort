function Archive_Extract(const F, DstDir: string): Integer;
var
    U: TUnZipper;
    Res: string;
    LastExt, Inner: string;
begin
    Result := 1;
    if Is_Zip_File(F) then
    begin
        U := TUnZipper.Create;
        try
            U.FileName := F;
            U.OutputPath := DstDir;
            try
                U.UnZipAllFiles;
                Result := 0;
            except
                Result := 1;
            end;
        finally
            U.Free;
        end;
        Exit;
    end;
    LastExt := Get_Compound_Ext_Last(F);
    if Is_Tar_Suffix(F) and HaveTool('tar') then
        Result := RunTool('tar', ['-xf', F, '-C', DstDir], Res)
    else if LastExt = '7z' then
        Result := RunTool('7z', ['x', '-o' + DstDir, F], Res)
    else if LastExt = 'rar' then
    begin
        if HaveTool('unrar') then
            Result := RunTool('unrar', ['x', F, IncludeTrailingPathDelimiter(DstDir)], Res)
        else
            Result := 127;
    end
    else if (LastExt = 'gz') and HaveTool('gzip') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'gzip -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end
    else if (LastExt = 'bz2') and HaveTool('bzip2') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'bzip2 -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end
    else if (LastExt = 'xz') and HaveTool('xz') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'xz -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end
    else if (LastExt = 'zst') and HaveTool('zstd') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'zstd -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end;
end;
