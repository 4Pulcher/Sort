function Fs_Norm(S: string): string;
begin
    Result := LowerCase(Trim(S));
    if (Result = 'ext2') or (Result = 'ext3') or (Result = 'ext4') then
        Result := 'ext';
    if (Result = 'hfs+') or (Result = 'hfsx') or (Result = 'hfsplus') then
        Result := 'hfs';
end;
