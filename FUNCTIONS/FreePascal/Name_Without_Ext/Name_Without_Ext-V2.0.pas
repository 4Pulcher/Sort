function Name_Without_Ext(const F: string): string;
var
    Dot: Integer;
begin
    Dot := LastDelimiter('.', F);
    if Dot > 1 then
        Result := Copy(F, 1, Dot - 1)
    else
        Result := F;
end;
