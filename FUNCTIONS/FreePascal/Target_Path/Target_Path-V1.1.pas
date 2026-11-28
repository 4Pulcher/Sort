function Target_Path(const Dir, Name, Ext: string; N: Integer): string;
begin
    if N > 0 then
        Result := Dir + '/' + Name + '~' + IntToStr(N)
    else
        Result := Dir + '/' + Name;
    if Ext <> '' then
        Result := Result + '.' + Ext;
end;
