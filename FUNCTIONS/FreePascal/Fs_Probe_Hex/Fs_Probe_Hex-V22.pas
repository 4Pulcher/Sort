function Fs_Probe_Hex(const H: string): string;
begin
    Result := '';
    if Copy(H, 1, 12) = '4c554b53babe' then begin Result := 'luks'; Exit; end;
    if Copy(H, 7, 16) = '4e54465320202020' then begin Result := 'ntfs'; Exit; end;
    if Copy(H, 7, 12) = '455846415420' then begin Result := 'exfat'; Exit; end;
    if Copy(H, 109, 10) = '4641543136' then begin Result := 'fat16'; Exit; end;
    if Copy(H, 109, 10) = '4641543132' then begin Result := 'fat12'; Exit; end;
    if Copy(H, 165, 10) = '4641543332' then begin Result := 'fat32'; Exit; end;
    if Copy(H, 129, 16) = '5f42485266535f4d' then begin Result := 'btrfs'; Exit; end;
    if Copy(H, 1, 8) = '58465342' then begin Result := 'xfs'; Exit; end;
    if Copy(H, 105, 12) = '526549734572' then begin Result := 'reiserfs'; Exit; end;
    if (Copy(H, 2049, 4) = '482b') or (Copy(H, 2049, 4) = '4858') then begin Result := 'hfs'; Exit; end;
    if Copy(H, 2161, 4) = '53ef' then begin Result := 'ext'; Exit; end;
    if Copy(H, 2105, 20) = '53574150535041434532' then begin Result := 'swap'; Exit; end;
end;
