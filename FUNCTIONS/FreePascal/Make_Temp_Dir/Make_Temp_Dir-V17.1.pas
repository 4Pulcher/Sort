function Make_Temp_Dir: string;
var
    Base, D: string;
    N: Integer;
begin
    Base := GetEnvironmentVariable('TMPDIR');
    if Base = '' then
        Base := '/tmp';
    N := 0;
    repeat
        D := IncludeTrailingPathDelimiter(Base) + 'sort.' + IntToStr(GetTickCount64)
             + '.' + IntToStr(N);
        Inc(N);
    until CreateDir(D) or (N > 100);
    Result := D;
end;
