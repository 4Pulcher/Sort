function File_Time(const F, Which: string): TDateTime;
var
    SB: TStat;
    Age: LongInt;
begin
    Result := 0;
    if Which = 'accessed' then
    begin
        if FpStat(F, SB) = 0 then
            Result := UnixToDateTime(SB.st_atime);
    end
    else if Which = 'created' then
    begin
        if FpStat(F, SB) = 0 then
            Result := UnixToDateTime(SB.st_ctime);
    end
    else
    begin
        Age := FileAge(F);
        if Age >= 0 then
            Result := FileDateToDateTime(Age);
    end;
end;
